#!/usr/bin/perl

# prenas la redaktitajn artikolojn el la poshtfako
# au alia dosiero donita en la komandlinio kaj
# analizas, sintakse kontrolas, metas en la vortaron
# kaj arkivas (per Git) ilin.
#
# voku:
#  processmail.pl [<mesagh-dosiero>]

use strict; use warnings;

use lib("/usr/local/bin");
use lib("./bin");
use process qw(sys_run my_name timestamp trim);
use mailsender;

use utf8; use open ':std', ':encoding(UTF-8)';

use MIME::Parser;
use MIME::Entity;
use Log::Dispatch;


######################### agorda parto ##################

our $CFG = {

	# kiom da informoj
	# verbose        => 1,
	dump           => $ENV{'DEBUG'}, #0,
	loglevel       => $ENV{'DEBUG'}? 'debug' : 'info',

	#$vokomail_url => "http://www.reta-vortaro.de/cgi-bin/vokomail.pl",
	xml_source_url => 'https://github.com/revuloj/revo-fonto/blob/master/revo',
	revo_url       => "http://purl.oclc.org/NET/voko/revo",

	# FARENDA: legu tiujn el sekreto(j)
	revoservo      => '[Revo-Servo]',
	revo_mailaddr  => 'revo@reta-vortaro.de',
	redaktilo_from => 'redaktilo@reta-vortaro.de',
	##$revolist    => 'wolfram',


	# FARENDA: legu tiujn el /docker swarm config/
	# baza agordo
	afido_dir    => "/var/afido", # $ENV{"HOME"}, # tmp, log
	dict_home    => $ENV{"HOME"},
	dict_etc     => $ENV{"HOME"}."/etc", #"/run/secrets", # redaktantoj

	# programoj
	#$xmlcheck     => '/usr/bin/rxp -V -s',
	git          => '/usr/bin/git',
	# -t ne subtenata de ssmtp
	#$rsync        => '/usr/bin/rsync -rv',
	rsync        => '/usr/bin/rsync -r --stats',
	#$sendmail     => '/usr/lib/sendmail -t -i',
	#$sendmail     => '/usr/lib/sendmail -i',
	#$patch        => '/usr/bin/patch',	

	# diversaj
	mail_begin   => '^From[^:]',
	possible_keys=> 'komando|teksto|shangho',
	commands     => 'redakt[oui]|aldon[oui]', # .'help[oui]|dokumento|artikolo|historio|propono'
	separator    => "=" x 50 . "\n"
};

$CFG->{dict_base} = "$CFG->{dict_home}/dict"; # xml, dok, dtd

$CFG->{revo_from} = "Reta Vortaro <$CFG->{revo_mailaddr}>";
$CFG->{signature} = "--\nRevo-Servo $CFG->{revo_mailaddr}\n"
	."retposhta servo por redaktantoj de Reta Vortaro.\n";

# dosierujoj
$CFG->{tmp}      = "$CFG->{afido_dir}/tmp";
$CFG->{log_mail} = "$CFG->{afido_dir}/log";
$CFG->{dtd_dir}  = "$CFG->{dict_base}/dtd";

$CFG->{mail_folder} = "/var/spool/mail/".process::my_name(); #/var/spool/mail/tomocero";
$CFG->{parts_dir}   = "$CFG->{afido_dir}/tmp/mailparts";
$CFG->{mail_error}  = "$CFG->{tmp}/mailerr";
$CFG->{mail_send}   = "$CFG->{tmp}/mailsend";
$CFG->{xml_temp}    = "$CFG->{tmp}/xml";
$CFG->{dtd_temp}    = "$CFG->{tmp}/dtd";

$CFG->{old_mail}    = "$CFG->{log_mail}/oldmail";
$CFG->{err_mail}    = "$CFG->{log_mail}/errmail";
$CFG->{prc_mail}    = "$CFG->{log_mail}/prcmail";

$CFG->{xml_dir}     = "$CFG->{dict_base}/xml";
$CFG->{git_dir}     = "$CFG->{dict_base}/revo-fonto";
$CFG->{dok_dir}     = "$CFG->{dict_base}/dok";

$CFG->{mail_local}  = "$CFG->{tmp}/mail";
$CFG->{editor_file} = "$CFG->{dict_etc}/voko.redaktantoj";
$CFG->{attachments} = "$CFG->{tmp}/mailatt/attchm".$$."_";


# preparu protokolon
our $LOG = Log::Dispatch->new(
	outputs => [
		#[ 'File',   min_level => 'debug', filename => 'logfile' ],
		[ 'Screen', min_level => $CFG->{loglevel} ],
	],
);

################ la precipa masho de la programo ##############

local $| = 1;

our $CTX = {
	editor     => '',
	mail       => '',
	article_id => '',
	mail_date  => '',
	shangho    => '',
	komando    => '',
	file_no    => 0
};

##@newarts    = ();

# tiel ni povas testi sub-funkciojn de ekstere:
MAIN() unless caller(); sub MAIN {


	#git_pull();
	my ($lg,$err) = process::git_cmd($CFG->{git}, 'pull');
	if ($err =~ m/fatal/x || $err =~ m/error/x || $lg =~ m/[CK]ONFLI/x) {
		# se okazas problemo puŝi la ŝanĝojn, ne sendu raportojn, sed tuj finu
		# kun eraro-stato, tio devus ankaŭ eviti la postan aldonon de konfirmoj/eraroj al
		# gistoj kaj permesi refari la tutan procedon...
		exit 1;
	}
	# sinkronigu revo/xml
	$LOG->info("$CFG->{rsync} $CFG->{git_dir}/revo/ $CFG->{xml_dir}/\n...");
	unless (-x "/usr/bin/rsync") {
		warn "Programo 'rsync' ne ekzistas aŭ ne estas lanĉebla!\n";
	}
	print sys_run($CFG->{rsync},"$CFG->{git_dir}/revo/","$CFG->{xml_dir}/");

	# vi povas retrakti specifan (antaŭan) poŝtdosieron, ekz-e se okazis
	# eraro kaj vi volas ripeti por ne perdi la redakton...
	my $mail_file = '';
	if ($ARGV[0]) {
		$mail_file = shift @ARGV;

	# normala procedo, kiam la poŝtdosiero estas tiu 
	# kreita per fetchmail+postfix
	} else {

		# chu estas poshto?
		if (not -s $CFG->{mail_folder}) {
			$LOG->info("neniu poshto en $CFG->{mail_folder}");
			exit;
		};

		# shovu la poshtdosieron
		rename($CFG->{mail_folder},$CFG->{mail_local});
		#`cp $CFG->{mail_folder} $CFG->{mail_local}`;

		$mail_file = $CFG->{mail_local};
	}

	## no critic (InputOutput::RequireBriefOpen)
	open my $MAIL, "<", "$mail_file" 
		or die "Ne povis malfermi $mail_file: $!\n";

	# legu unu post al alia retpoŝtojn el $mail_file
	# komencon de retpoŝto readmail() rekonas per From:...
	while (my $file = readmail($MAIL)) {

		$LOG->info('-' x 50, "");

		# preparu por la nova mesagho
		$CTX->{editor} = '';
		$CTX->{shangho} = '';
		$CTX->{article_id} = '';

		my $parser = MIME::Parser->new;
		$parser->output_dir($CFG->{parts_dir});
		$parser->output_prefix("part");
		$parser->output_to_core(20000);        

		# malfermu kaj enlegu la mesaghon
		open my $ML, "<", $file or do {
			warn "Ne eblis malfermi la mesaĝon por legi ĝin: $file\n";
			next;
		};

		my $entity = $parser->read($ML);
		unless ($entity) {
			warn "Ne eblis analizi la MIME-mesaghon.\n";
			next;
		}

		# eligu iom da informo pri la mesagho
		my $header = $entity->head();
		
		$LOG->info("From    : ", $header->get('From'));
		$LOG->info("Reply-To: ", $header->get('Reply-To') || ""); 

		$LOG->debug(
			"Subject : ", $header->get('Subject'),
			"Cnt-Type: ", $header->get('Content-Type')
		);
		$entity->dump_skeleton if ($CFG->{dump});

		chomp($CTX->{mail_date} = $header->get('Date'));

		# analizu la enhavon de la mesagho
		process_ent($entity);

		# purigado
		$entity->purge();
		close $ML;
	}

	close $MAIL;

	## use critic

	# sendu raportojn
	$LOG->info("elsendas raportojn...");

	#send_reports();

	if (-s $CFG->{mail_send} > 10) {
		my $mailer = mailsender::smtp_connect;
		send_reports($mailer);
		mailsender::smtp_quit($mailer);
	}


	##send_newarts_report();
	$LOG->info("puŝas ŝanĝojn al git...");
	($lg,$err) = process::git_cmd($CFG->{git}, 'push', 'origin', 'master');
	if ($err =~ m/fatal/ || $err =~ m/error/) {
		# se okazas problemo puŝi la ŝanĝojn, ne sendu raportojn, sed tuj finu
		# kun eraro-stato...
		exit 1;
	}

	my $filename = timestamp();    

	# arkivu la poshtdosieron
	if ($mail_file eq $CFG->{mail_local}) {
		$LOG->info("\nshovas $CFG->{mail_local} al $CFG->{old_mail}/$filename");
		rename($CFG->{mail_local},"$CFG->{old_mail}/$filename");
	}

	if (-e $CFG->{mail_error}) {
		$LOG->info("shovas $CFG->{mail_error} al $CFG->{err_mail}/$filename");
		rename($CFG->{mail_error},"$CFG->{err_mail}/$filename");
	}

	if (-e $CFG->{mail_send}) {
		$LOG->info("shovas $CFG->{mail_send} al $CFG->{prc_mail}/$filename");
		rename($CFG->{mail_send},"$CFG->{prc_mail}/$filename");
	}

	exit 0;

} # MAIN

###################### analizado de la mesaghoj ################

# legas el $MAIL liniojn ĝis sekva FROM
# konservas la legitajn liniojn en dosiero sub /tmp/ kaj
# redonas ties nomon
sub readmail {
	my $MAIL = shift;
	my $lastpos;
	
	# legu unuan linion de retpoŝto
	$CTX->{mail} = <$MAIL>;

	# legu pliaj liniojn de retpoŝto
	# ĝis aperas $mail_begin (From:)
	while (<$MAIL>) {
		if (/$CFG->{mail_begin}/x) {
		    seek($MAIL,$lastpos,0); # reiru unu linion
		    last;
		} else {
		    $CTX->{mail} .= $_;
		    $lastpos = tell($MAIL);
		};
	};

	if ($CTX->{mail}) {
	    my $fn = "/tmp/".$$."mail";
	    if ( open my $out, ">", "$fn" ) {
			print $out $CTX->{mail};
			close $out;
			return $fn;
		}
	}

    return; 
}
		

sub process_ent {
    my $entity = shift;
    my $parttxt;
    my $xmltxt = '';
    my $first_line;

    # kontrolu, chu temas pri redaktoro au helpkrio
    unless ($CTX->{editor} = is_editor($entity->head->get('from'),
				$entity->head->get('reply-to'))) 
    { 

	# chu temas pri helpkrio?
	# tia helppeto validas nur en simplaj mesaghoj
##    my $IO;
##	if ($entity->mime_type =~ m|^text/plain|) {
##	    $IO = $entity->bodyhandle->open("r"); 
##	    $first_line = $IO->getline(); $IO->close;
##	    if ($first_line =~ /^\s*help/) {
##
##		cmd_help($entity->head->get('reply-to') 
##			 || $entity->head->get('from'));
##
##		print "komando \"helpo\"\n" 
##		    if ($CFG->{verbose});
##		return;
##	    };
##	};
	    
		print "!!! ".$entity->head->get('from')." ne estas redaktoro "
			."nek petas pri helpo !!!\n"
			."\tsubject: ".$entity->head->get('subject')."\n";
		print "\tstart of mail: $first_line\n---\n" if ($first_line);
		save_errmail();
		return; # ne respondu al SPAMo
    }
	
    $LOG->debug("redaktisto: $CTX->{editor}");

    # unuparta mesagho
    if (! $entity->is_multipart) {
		$LOG->debug("single part message");

		# elprenu la tekston
		$parttxt = $entity->bodyhandle->as_string;   

		# Opera uzas linirompojn anstatau "&", sed ankau havas aliloke linirompojn
		if (($entity->head->get('user-agent') =~ /Opera/sx ) and        
			($entity->head->get('content-type')
					=~  /format=flowed/sx))      # Opera
		{
			$parttxt =~ s/&/%26/sgx;
		$parttxt =~ s{
				\n(teksto|shangho|ago)=
			}{\&\n$1=}sgx;
		}

	# TTT-formularo?
        if ((($entity->head->get('subject')
                 =~ /Microsoft.*Internet.*lorer/sx) 

                or ($entity->head->get('content-type')
		 =~  /POSTDATA\.ATT/sx)

                or ($entity->head->get('content-type')
                 =~  /format=flowed/sx)      # Opera

		or ($entity->head->get('subject')
		 =~ /form\s+post/six)

                or ($entity->head->get('x-mailer')
                 =~ /Apple\sMail/x)
                )
                and ($parttxt =~ /^\s*komando=redakto&/x)

                or ($entity->mime_type
                    =~ m|application/x-www-form-urlencoded|x)) { 
	    $LOG->debug("URL encoded form");
	    urlencoded_form($parttxt);
	    return;
	# normala mesagho
	} else {
	    $LOG->debug("normala mesagho");
	    normal_message($parttxt);
	    return;
	}
	
    # plurparta MIME-mesagho
    } else {
	my $num_parts = $entity->parts;
	$LOG->debug("num of parts: ", $num_parts);

	# trairu chiujn partojn
	for (my $i = 0; $i < $num_parts; $i++) {
	    my $part = $entity->parts($i);
	    $LOG->debug($part->mime_type, "");

	    # elprenu la tekston
	    unless ($part->bodyhandle) { next; } # ignoru plurpartajn partojn
	    $parttxt = $part->bodyhandle->as_string;

	    # chu temas pri TTT-formularo?
	    if ((($entity->head->get('subject') 
		 =~ /Microsoft.*Internet.*lorer/sx) 
                or ($part->head->get('content-type')
		    =~  /POSTDATA\.ATT/sx))
		and ($parttxt =~ /^\s*komando=redakto&/x)
		or ($part->mime_type 
		    =~ m|application/x-www-form-urlencoded|x)) {
		
		# TTT-formularo
		urlencoded_form($parttxt);
		return;
	    }

	    # ekzamenu, chu en la partoj estas komando kaj/au xml
	    if ( $parttxt =~ m{^
			\s*($CFG->{commands})\s*:
		}six ) {
			$CTX->{komando} = $1;
			$LOG->debug("komando $CTX->{komando} en parto $i");
			if ( $CTX->{komando} =~ m{^
				(help|dokument|artikol|histori)
			}x ) {
				normal_message($parttxt);
			} else {
				# chu krome enhavas la xml-tekston?
				if ($parttxt =~ /<\?xml/sx) {
					$LOG->debug("xml en parto $i");
					normal_message($parttxt);
					return;
				} else {
					# supozu, ke estas nur la komando kaj trovu la reston
					$CTX->{komando} = $parttxt;
				}
			}
	    } elsif ($parttxt =~ /^\s*<\?xml/sx) {
			$LOG->debug("xml en parto $i");
			# memoru la xml-tekston
			$xmltxt = $parttxt;
	    }

	    # se ambau - komando kaj xml - estas trovitaj, daurigu
	    if ($CTX->{komando} and $xmltxt) {
			normal_message("$CTX->{komando}\n\n$xmltxt");
			return;
	    }
	}
	# en la plurparta mesagho shajne ne trovighis la serchita
	report("ERARO   : Ne trovighis komando kaj/au XML-teksto en la "
		   ."plurparta mesagho");
    }

	return;
}

# kontrolas ĉu unu el la retadresoj from: aŭ reply-to:
# apartenas al registrita redaktanto
sub is_editor {
    my $from_addr = shift;
    my $reply_addr = shift;
    my $res_addr = '';

    chomp $from_addr;
    chomp $reply_addr;

    my $pos1 = index($from_addr,$CFG->{redaktilo_from});
    #my $pos2 = index($from_addr,$CFG->{redaktilo_from2});

	my $email_addr;

	# se la retpoŝto venas de la redaktilo,
	# la redaktanto troviĝu en reply-to
	# (ĉar intertempe la redaktilo submetas al
	# la datumbazo kaj ne plu sendas redaktojn
	# retpoŝte, tio ne devus okazi plu!
    if ($pos1 == 0 || $pos1 == 1) {
		$email_addr = $reply_addr;
    } else {
		$email_addr = $from_addr;
    }
    
    $email_addr =~ s{
		\(
		[^\)]+
		\)
	}{}sx; # nomindiko laŭ malnova maniero

	# forigu marĝenajn spacsignojn
    $email_addr =~ s/^\s+//sx;
    $email_addr =~ s/\s+$//sx;

	# forigu ĉion antaŭ kaj post la la unua retadreso
	# inkl. la angulajn krampojn
    $email_addr =~ s{^
		.*<(
		[a-z0-9\.\_\-]+
		\@
		[a-z0-9\._\-]+
		)>
		.*$}{<$1>}six;

    unless ( $email_addr =~ m{
		<?
		[a-z0-9\.\_\-]+
		\@
		[a-z0-9\._\-]+
		>?
	}ix ) { 
		return; # ne estas valida retadreso
    }

    # serchu en la dosiero kun redaktoroj
	## no critic (InputOutput::RequireBriefOpen)
    if (open my $edi, "<", $CFG->{editor_file}) {
		while (<$edi>) {
			chomp;
			unless (/^#/x) {
				if (index(lc($_),lc($email_addr)) >= 0) {
					$LOG->debug("retadreso trovita en: $_");
					# /^([a-z'"\-\.\s]*<[a-z\@0-9\.\-_]*>)/i;
					if ( m{^(
						[\wćáàéè'"\-\.\s]*
						<
						[a-z\@0-9\.\-_]*
						>
					)}ix ) {
						$res_addr = $1;
					}
					unless ($res_addr) {
						print "ne povis ekstrakti la adreson el $_\n";
					} else {
						print "sendadreso de la redaktoro: $res_addr\n" 
						if ($CFG->{debug});
					}
					return $res_addr;
				}
			}
		}
		close $edi;
	}
	## use critic
		
    return; # ne trovita
}


sub urlencoded_form {
    my $text = shift;
    my %content = ();
    my ($key,$value);

    $text =~ s/!?\n//sgx;
	foreach my $pair (split ('&',$text)) {
		if ($pair =~ m{
			(.*?)=(.*)
		}x) {
			($key,$value) = ($1,$2);
			if ($key =~ /^(?:$CFG->{possible_keys})$/x) {
			$value =~ s/\+/ /gx; # anstatauigu '+' per ' '
			$value =~ s{%(..)}{pack('c',hex($1))}segx;
			$content{$key} = $value;
			};
		}
    };           

    komando($content{'komando'},$content{'shangho'},$content{'teksto'});

	return;
}

sub normal_message {
    my $text = shift;
    my ($cmd,$arg,$xml);

    if ($text =~ s{
		^[\s\n]*
		($CFG->{commands})[\ \t]*:
		[\ \t]*
		(.*?)\n
	}{}six) {
		$cmd = $1;
		$arg = $2;

		# legu ĉion ghis malplena linio au "<?xml..."
		while (($text !~ /^\s*\n/x) and ($text !~ /^\s*<\?xml/ix)) {
			if ($text =~ s{
				^[ \t]*
				(.*?)
				\n
			}{}x) {
				$arg .= $1;
			}
		}

		# la resto povus esti la artikolo
		$text =~ s/^[\s\n]*//x;
		
		# kaze, ke iu subskribo finas la mesaghon, forigu
		# chion post </vortaro>
		$text =~ s{
			(<\/vortaro>).*$
		}{$1}sx;

		# anstataŭigu nbsp per spacoj linikomence, kion faras ekz. retposhtilo Evolution
		# $text =~ s/^(\240+)/tr_nbsp($1)/me;
        $text =~ s{
          ^(
          (?:\302\240)+
          )
        }{tr_nbsp($1)}megx;
		
		if ($text) {
			$xml = $text;
		}

		komando($cmd,$arg,$xml);

    } else {
		# sekurigu la dosieron
		open my $msg, ">", "$CFG->{tmp}/_err_msg" or do {
			warn "Ne povis malfermi $CFG->{tmp}/_err_msg: $!\n";
			report("ERARO   : nekonata komando en la poshtajho");
			return;
		};
		print $msg $text;
		close $msg;

		# kelkaj pseudaj variabloj necesaj
		$CTX->{article_id} = "???.xml";
		$CTX->{komando} = "???";
		$CTX->{hangho} = "???";

		# raportu eraron
		report("ERARO   : nekonata komando en la poshtajho","$CFG->{tmp}/_err_msg");
    }

	return;
}

sub komando {
    my ($cmd,$arg,$txt) = @_;

    # memoru por poste
    $CTX->{komando} = $cmd;

	if ($cmd =~ /^redakt[oui]/ix) {
		cmd_redakt($arg, $txt);

    } elsif ($cmd =~ /^aldon[oui]/ix) {
		cmd_aldon($arg, $txt);

    } else {
		report("ERARO   : nekonata komando $cmd");
		return;
    }

	return;
}

sub save_errmail {
    open my $errmail, ">>", "$CFG->{mail_error}" or do {
		warn "Ne povis malfermi $CFG->{mail_error}: $!\n";
		return;
    };
    print $errmail $CTX->{mail};
    close $errmail;
    $LOG->info("erara mesagho sekurigita al $CFG->{mail_error}");

	return;
}


######################### respondoj al sendintoj ###################

sub report {
    my ($msg,$file) = @_;
    my ($attachment,$text);
    
    $LOG->info("$msg");

    # donu provizoran nomon al kunsendajho
    if ($file) {

		# enmetu "redakto: $shanghoj" komence
		if ($file =~ m/\.xml$/x) {
			open my $in, "<", $file or do {
				warn "Ne povis malfermi $file: $!\n";
				goto "MOVE_FILE";
			};
			$text = do { local $/ = undef, <$in>};
			close $in;

			open my $out, ">", "$file" or do {
				warn "Ne povis malfermi $file: $!\n";
				goto "MOVE_FILE";
			};
			print $out "$CTX->{komando}: $CTX->{shangho}\n\n";
			print $out $text;
			close $out;
		}
		
MOVE_FILE:
		# donu provizoran nomon al la dosiero
		$CTX->{file_no}++;
		$attachment = "$CFG->{attachments}$CTX->{file_no}";
		rename($file,$attachment);
    }

    # skribu informon en $mail_send por poste sendi raporton al $CTX->{editor}
    open my $smail, ">>", "$CFG->{mail_send}" 
		or do { warn "Ne povis malfermi $CFG->{mail_send}: $!\n"; return; };

    print $smail "sendinto: $CTX->{editor}\n";
    print $smail "dosieroj: $attachment\n" if ($file);
    print $smail "senddato: $CTX->{mail_date}\nartikolo: $CTX->{article_id}\n";
    print $smail "shanghoj: $CTX->{shangho}\n" if ($CTX->{shangho});
    print $smail "$msg\n$CFG->{separator}";
    close $smail;

	return;
}

sub send_reports {
	my $mailer = shift;

    my $newline = $/;
    my %reports = ();
    my %dosieroj = ();
    my ($mail_addr,$message,$mail_handle,$file,$art_id,$marko,$dos);

    # legu la respondojn el $mail_send
    if (-e $CFG->{mail_send}) {
		
		local $/ = $CFG->{separator};
		open my $smail, "<", $CFG->{mail_send} or do {
			warn "Ne povis malfermi $CFG->{mail_send}: $!\n";
			return;
		};

		while (<$smail>) {
			# elprenu la sendinton
			if (s{
				^sendinto:\ŝ*
				([^\n]+)
				\n
			}{}x) {
				$mail_addr = $1;
				# chu dosierojn sendu?
				if (s{
					^dosieroj:\s*
					([^\n\s]+)
					\n
				}{}x) {
					$dos = $1;
					if ($_ =~ m{
						artikolo:\s*
						([^\n]+)
						\n
					}sx) { 
						$art_id = $1; 
					};
					# foje jam malaperis la aldonenda dosiero pro antaŭa eraro, kio kaŭzus
					# senfinan sendadon de ĉiam la sama eraro..., do aldonu nur se la dosiero ekzistas
					if (-e $dos) {
						$dosieroj{$mail_addr} .= "$dos $art_id|";
					}
				}
				$reports{$mail_addr} .= $_;
			} else {
				warn "Ne povis elpreni sendinton el $_\n";
				next;
			}
		}
		close $smail;
		local $/ = $CFG->{newline};

		# forsendu la raportojn
		while (($mail_addr,$message) = each %reports) {
			$dos = $dosieroj{$mail_addr};
			$mail_addr =~ s{
				.*<([a-z0-9\.\_\-@]+)>.*
			}{$1}x;
			
			# preparu mesaghon
			$message = "Saluton!\n"
			."Jen raporto pri via(j) sendita(j) artikolo(j).\n\n"
				.$CFG->{separator}.$message."\n".$CFG->{signature};
			
			$mail_handle = build MIME::Entity(Type=>"multipart/mixed",
							From=>$CFG->{revo_from},
							To=>"$mail_addr",
							Subject=>"$CFG->{revoservo} - raporto");

			$LOG->info("AL: <$mail_addr>: [[[\n$message\n]]]");
			
			$mail_handle->attach(Type=>"text/plain",
					Encoding=>"quoted-printable",
					Data=>$message);
			
			# alpendigu dosierojn
			if ($dos) {
				for my $file (split (/\|/x,$dos)) {
					if ($file =~ m{
						^\s*
						([^\s]+) # parto ĝis unua spaco
						\s+
						(.+?)    # parto post unua spaco
						\s*$
					}x) {
						$file = $1;
						$art_id = $2;

						if ($art_id =~ m{  # inter du dolarsignoj
							^\044
							([^\044]+)
							\044$
						}x) {
							$art_id = $1;
							if ($art_id =~ m{
								^Id:\s+     # Id:
								([^\ ,\.]+  # dosiernomo
								\.xml),v    # fino
							}x) {
								$marko = $1;
							}

						} else {
							$marko = $art_id;
						}
					} else { $art_id = $file; $marko=$file; }
					
					$LOG->debug("attach: $file");
					if (-e $file) {
						$mail_handle->attach(Path=>$file,
								Type=>'text/plain',
								Encoding=>'quoted-printable',
								Disposition=>'attachment',
								Filename=>$marko,
								Description=>$art_id);
					}
				}
			}
			
			# forsendu
			$LOG->info("sendi nun...");
			## unless (open SENDMAIL, "| $sendmail '$mail_addr'") {
			## 	warn "Ne povas dukti al $sendmail: $!\n";
			## 	next;
			## }
			## $mail_handle->print(\*SENDMAIL);
			## close SENDMAIL;

			# forsendu
			unless (mailsender::smtp_send($mailer,$CFG->{revo_from},$mail_addr,$mail_handle)) {
				warn("Ne povas forsendi retpoŝtan raporton!\n");
				next;
			}

		} # while

	# forigu $mail_send
	# unlink($mail_send);
    } # if

	return;
}


###################### komandoj kaj helpfunkcioj ##############


## sub cmd_help {
##     my $mail_addr = shift;
##     my ($mail_handle);
##     
##     # sendu helpdokumenton al la sendinto
##     $mail_handle = build MIME::Entity(Type=>"multipart/mixed",
## 				      From=>$revo_from,
## 				      To=>"$mail_addr",
## 				      Subject=>"$revoservo - helpo");
## 	    
##     $mail_handle->attach(Type=>"text/plain",
## 			 Encoding=>"quoted-printable",
## 			 Data=>"Saluton!\n\n"
## 			."Jen informoj pri la uzo de Revo-Servo.");
## 
##     $mail_handle->attach(Path=>$file,
## 			 Type=>'text/plain',
## 			 Encoding=>'quoted-printable',
## 			 Disposition=>'attachment',
## 			 Filename=>"$dok_dir/helpo.txt",
## 			 Description=>"helpo pri Revo-servo");
## 
##     # forsendu	
##     # unless (open SENDMAIL, "|$sendmail $mail_addr") {
## 	# 	warn "Ne povas dukti al $sendmail: $!\n";
## 	# 	return;
##     # }
##     # $mail_handle->print(\*SENDMAIL);
##     # close SENDMAIL;
## 
## 	# forsendu
## 	my $mailer = mailsender::smtp_connect;
## 	unless (mailsender::smtp_send($mailer,$revo_from,$mail_addr,$mail_handle)) {
## 		warn("Ne povas forsendi retpoŝtan raporton!\n");
## 		return;
## 	}
## 	mailsender::smtp_quit($mailer);
## 
## }


sub cmd_redakt {
    my ($shangh, $teksto) = @_;
    my ($id, $art, $err);

    $CTX->{shangho} = $shangh; # memoru por poste

	# forigu ne-askiajn signojn, ĉu ankoraŭ necesa?
    $CTX->{shangho} =~ s{[\200-\377]}{?}gx; # 

    # uniksajn linirompojn!
    $teksto =~ s{\r\n}{\n}sgx;

    # aldonu finan linirompon se mankas
    $teksto =~ s{
		<\/vortaro>?$
	}{<\/vortaro>\n}sx;

    # pri kiu artikolo temas, troviĝas en <art mrk="...">
	if ( ($id) = $teksto =~ m{
		<art[^>]*
		\bmrk\s*=\s*"([^\"]*)"
	}sx ) {
		$LOG->info("artikolo: $id");
		$CTX->{article_id} = $id;

		# ekstraktu dosiernomon el $Id: ...
		#$id =~ /^\044Id: ([^ ,\.]+)\.xml,v\s+([0-9\.]+)/;
		$art = extract_article($id);
	} else {
		report("ERARO   : Artikolmarko ne troviĝis en la artikolo.\n");
		return;
	}

    unless ($art =~ m{^
		[a-z0-9_]+
	$}ix) {
		report("ERARO   : Ne valida artikolmarko $art. Ĝi povas enhavi nur "
	      ."literojn, ciferojn kaj substrekon.\n");
		return;
    }

    if (check_xml($teksto,0)) {
		checkin($art,$id);
    }

	return;
}

sub check_xml {
    my ($teksto,$nova) = @_;
    #my $err;
	my $fname = "$CFG->{xml_temp}/xml.xml";

    # aldonu dtd symlink se ankoraŭ mankas
    symlink("$CFG->{dtd_dir}","$CFG->{xml_temp}/../dtd") ;
#	|| warn "Ne povis ligi de $CFG->{dtd_dir} al $CFG->{xml_temp}/../dtd\n";

    # skribu la dosieron provizore al tmp
    open my $xml,">", "$CFG->{xml_temp}/xml.xml" or do {
		warn "Ne povis malfermi $CFG->{xml_temp}/xml.xml: $!\n";
		return;
    };

    print $xml $teksto;
    close $xml;

	my $err = process::checkxml('xml',$fname,$nova);

    if ($err) {
		$err .= "\nkunteksto:\n".process::xml_context($err,$fname);
		$LOG->info("XML-eraroj:\n$err");

		report("ERARO   : La XML-dosiero enhavas la sekvajn "
			."sintakserarojn:\n$err",$fname);
		return;
    } else {
		$LOG->debug("XML: en ordo");
		return 1;
    }
}

sub checkin {
    my ($art,$id) = @_;
    my ($log,$err,$edtr,$teksto);

    # kontrolu chu ekzistas shangh-priskribo
    unless ($CTX->{shangho}) {
	report("ERARO   : Vi fogesis indiki, kiujn shanghojn vi faris "
	    ."en la dosiero.\n","$CFG->{tmp}/xml.xml");
        return;
    } 
    $CTX->{shangho} = lat3_utf8($CTX->{shangho});
    $LOG->info("shanghoj: $CTX->{shangho}");

    # skribu la shanghojn en dosieron
    $edtr = $CTX->{editor};
    $edtr =~ s{
		\s*<(.*?)>\s*
	}{}x;

    if (open my $msg, ">", "$CFG->{tmp}/shanghoj.msg") {
	    print $msg "$edtr: $CTX->{shangho}";
    	close $msg;
	} else {
		warn "Ne eblas skribi al tmp/shanghoj.msg: $!\n";
	}

    # kontrolu, chu la artikolo bazighas sur la aktuala versio
    my $ark_id = get_archive_version($art);
	# estis problemo, ke versioj de CVS kaj Git povis devii je sekundo
	# por mildigi la problemon ni ignoris la tempon:
    if (substr($ark_id,0,-19) ne substr($id,0,-19)) {

		# versi-konflikto
		report("ERARO   : La de vi sendita artikolo\n"
			."ne bazighas sur la aktuala arkiva versio\n"
			."($ark_id)\n"
			."Bonvolu preni aktualan version el la TTT-ejo. "
			."($CFG->{xml_source_url}/$art)\n","$CFG->{xml_temp}/xml.xml");
		return;
    }

    my $xmlfile="$art.xml";

	# checkin in Git
    rename("$CFG->{xml_temp}/xml.xml","$CFG->{git_dir}/revo/$xmlfile");

	chdir($CFG->{git_dir});
	checkin_git("revo/$xmlfile",$edtr);

	unlink("$CFG->{tmp}/shanghoj.msg");

	return;
}


sub checkin_git {
	my ($xmlfile,$edtr) = @_;

	#incr_ver("$git_dir/$xmlfile");
	process::incr_ver($xmlfile,"$CFG->{tmp}/shanghoj.msg");

	my ($log1,$err1) = process::git_cmd($CFG->{git}, 'add', $xmlfile);
	my ($log2,$err2) = process::git_cmd($CFG->{git}, 'commit', '-F', "$CFG->{tmp}/shanghoj.msg");

	# ekz. git.log se estas ŝanĝo:
	#	[master 601545b1d0] +spaco
	#	Author: Revo <revo@steloj.de>
	#	1 file changed, 1 insertion(+), 1 deletion(-)
	
	# ekz. git.log se ne estas ŝanĝo:
	#On branch master
	#Your branch is ahead of 'origin/master' by 1 commit.
	#  (use "git push" to publish your local commits)
	#nothing to commit, working tree clean

    # se log estas ne malplena, (kaj enhavas "1 file") - chio en ordo, 
    # se err estas ne malplena  - eraro
    # se log enhavas 'nothing to commit', la dosiero ne estas shanghita   

    # raportu erarojn
    if ($log2 =~ m{
			nothing\s
			to\s
			commit
	}sx) {
		report("ERARO   : La sendita artikolo shajne ne diferencas de "
			."la aktuala versio.");
		return;
    } elsif ($err2 !~ m/^\s*$/sx) {
		report("ERARO   : Eraro dum arkivado de la nova artikolversio:\n"
			."$log1\n$log2\n$err1\n$err2\n","$CFG->{tmp}/xml.xml");
		return;
    }

    # raportu sukceson 
    report("KONFIRMO: $log2");
	return 1;
}


sub cmd_aldon {
    my ($art, $teksto) = @_;
    my ($id, $err);

    # kio estu la nomo de la nova artikolo
    $art =~ s/^\s+//sx;
    $art =~ s/\s+$//sx;
    
    unless ($art =~ m{^
		[a-z0-9_]+
	$}sx) {
		report("ERARO   : Ne valida nomo por artikolo. \"$art\".\n"
			."Ghi konsistu nur el minuskloj, substrekoj kaj ciferoj.\n");
		return;
    }
    $CTX->{shangho} = $art; # memoru por poste

    # uniksajn linirompojn!
    $teksto =~ s{\r\n}{\n}sgx;

    # la marko estu "\044Id\044"
    $teksto =~ s{
		<art[^>]*>
	}{<art mrk="\044Id\044">}sx;
    $LOG->info("nova artikolo: $art");

    # bezonighas article_id en kazo de eraro
    $CTX->{article_id} = "\044Id: $art.xml,v\044";

    # kontrolu, chu la dosiernomo estas ankorau uzebla
    if (-e "$CFG->{xml_dir}/$art.xml") {
		report ("ERARO   : Artikolo kun la dosiernomo $art.xml jam ekzistas\n"
			."Bv. elekti alian nomon por la nova artikolo.\n");
		return;
    }

    # kontroli la sintakson
    if (check_xml($teksto,1)) {
		checkinnew($art);
    }

	return;
}

sub checkinnew {
    my ($art) = @_;
    my ($log,$err,$edtr,$teksto);

    $CTX->{shangho} = "nova artikolo";
    $LOG->info("shanghoj: $CTX->{shangho}");

    # skribu la shanghojn en dosieron
    $edtr = $CTX->{editor};
    $edtr =~ s{\s*<(.*?)>\s*}{}x;

    if (open my $msg, ">", "$CFG->{tmp}/shanghoj.msg") {
	    print $msg "$edtr: $CTX->{shangho}";
    	close $msg;
	} else {
		warn "Ne eblas skribi al $CFG->{tmp}/shanghoj.msg: $!\n";
	}

	# checkin in Git
	my $repo_art_file = "$CFG->{git_dir}/revo/$art.xml";
	rename("$CFG->{xml_temp}/xml.xml",$repo_art_file);

	#chdir($git_dir);
	checkinnew_git($repo_art_file,$edtr);

	unlink("$CFG->{tmp}/shanghoj.msg");

	return;
}


sub checkinnew_git {
	my ($xmlfile,$edtr) = @_;

	process::init_ver("$xmlfile","$CFG->{tmp}/shanghoj.msg");

	my ($log1,$err1) = process::git_cmd($CFG->{git}, 'add', $xmlfile);
	my ($log2,$err2) = process::git_cmd($CFG->{git}, 'commit', '-F', "$CFG->{tmp}/shanghoj.msg");

	# ekz. git.log se estas ŝanĝo:
	#	[master 601545b1d0] +spaco
	#	Author: Revo <revo@steloj.de>
	#	1 file changed, 1 insertion(+), 1 deletion(-)
	
	# ekz. git.log se ne estas ŝanĝo:
	#On branch master
	#Your branch is ahead of 'origin/master' by 1 commit.
	#  (use "git push" to publish your local commits)
	#nothing to commit, working tree clean

    # se log estas ne malplena, (kaj enhavas "1 file") - chio en ordo, 
    # se err estas ne malplena  - eraro
    # se log enhavas 'nothing to commit', la dosiero ne estas shanghita   

    # raportu erarojn
    if ($log2 =~ m{
		nothing\s
		to\s
		commit
	}sx) {
		report("ERARO   : La sendita artikolo shajne ne diferencas de "
			."la aktuala versio.");
		return;
    } elsif ($err2 !~ m/^\s*$/sx) {
		report("ERARO   : Eraro dum arkivado de la nova artikolversio:\n"
			."$log1\n$log2\n$err1\n$err2\n","$CFG->{tmp}/xml.xml");
		return;
    }

    # raportu sukceson 
    report("KONFIRMO: $log2");
	return 1;
}

sub get_archive_version {
    my ($art) = @_;
    my $xmlfile = "$CFG->{xml_dir}/$art.xml";

    # legu la ĝisnunan artikolon
	# KOREKTU: ĉe nova dosiero tiu atendeble ne ekzistas
	open my $xml, "<", $xmlfile or do {
		warn "Ne povis legi $xmlfile: $!\n";
		return;
    };
	my $txt = do { local $/ = undef, <$xml>};
    close $xml;

    # pri kiu artikolo temas, troviĝas en <art mrk="...">
	my $id;
	if ( ($id) = $txt =~ m{
		<art[^>]*
		\bmrk\s*=\s*"([^"]*)"
	}sx ) {
    	print "malnova artikolo: $id\n" if $CFG->{debug};
	}

    return $id;
}

sub extract_version {
    my $id = shift;
    # ekstraktu version el $Id: ...
    unless ($id =~ m{^
		\044Id:\s+ # $Id:
		[^\ ,\.]+  # dosiernomo
		\.xml,v\s+ # finaĵo
		([0-9\.]+) # versio
		}x) {
		report ("ERARO   : Artikol-marko havas malĝustan sintakson\n");
		warn "$id ne enhavas version\n";
		return '???';
    } else {
		return $1;
    }
}

sub extract_article {
    my $id = shift;
    # ekstraktu dosiernomon el $Id: ...
    unless ($id =~ m{^
		\044Id:\s+  # $Id:
		([^\ ,\.]+) # dosiernomo
		\.xml,v\s+  # finaĵo
		[0-9\.]+    # versio
	}x) {
		report ("ERARO   : Artikol-marko havas malĝustan sintakson\n");
		warn "$id ne enhavas dosiernomon\n";
		return '???';
    } else {
		return $1;
    }
}

sub lat3_utf8 {
    my $text = shift;

    # konverti la e-literojn de Lat-3 al utf-8
	## no critic (RegularExpressions::RequireExtendedFormatting)
    $text =~ s/\306/\304\210/g; #Cx
    $text =~ s/\330/\304\234/g; #Gx
    $text =~ s/\246/\304\244/g; #Hx 
    $text =~ s/\254/\304\264/g; #Jx
    $text =~ s/\336/\305\234/g; #Sx
    $text =~ s/\335/\305\254/g; #Ux
    $text =~ s/\346/\304\211/g; #cx
    $text =~ s/\370/\304\235/g; #gx
    $text =~ s/\266/\304\245/g; #hx
    $text =~ s/\274/\304\265/g; #jx
    $text =~ s/\376/\305\235/g; #sx
    $text =~ s/\375/\305\255/g; #ux

    return $text;
}

sub tr_nbsp {
    my $str = shift;
    $str =~ tr/\240\302/\040/; 
    return $str
}

# fino
1;
