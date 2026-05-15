#!/usr/bin/perl

# prenas la redaktitajn artikolojn el loka
# dosierujo kreita per elŝutado de Github-gistoj
# kaj analizas, sintakse kontrolas
# kaj arkivas (per Git) ilin.
#
# voku:
#  processgist.pl

use strict; use warnings;

use MIME::Entity;
use Log::Dispatch;
use LWP::UserAgent;

use Encode;
use utf8; use open ':std', ':encoding(UTF-8)';

use File::Copy qw(copy);
use Data::Dumper;

use lib("/usr/local/bin");
use lib("./bin");
use process qw( timestamp trim );
use mailsender;

######################### agorda parto ##################

our $CFG = {
	# kiom da informoj
	#verbose      => 1,
	#debug        => 1,
	loglevel     => 'info', # 'debug', 'info'...

	# se SERVILO ne estas aparte difinita ni uzas reta-vortaro.de
	submeto_url  => 'https://reta-vortaro.de',
	netloc       => 'reta-vortaro.de:443',
	realm        => 'Restricted Content',


	#$afido_dir    => "/var/afido"; # tmp, log
	dict_home     => $ENV{"HOME"}, # por testi: $ENV{'PWD'},
	dict_etc      => $ENV{"HOME"}."/etc", #"/run/secrets", # redaktantoj
	#$vokomail_url => "http://www.reta-vortaro.de/cgi-bin/vokomail.pl";
	xml_source_url  => 'https://github.com/revuloj/revo-fonto/blob/master/revo',
	revo_url      => 'http://purl.oclc.org/NET/voko/revo',
	#$mail_folder  => "/var/spool/mail/tomocero";

	revoservo     => '[Revo-Servo]',
	revo_mailaddr => 'revo@reta-vortaro.de',
	#$redaktilo_from=> 'revo-servo@steloj.de';

	separator    => " => " x 80 . "\n",

	# programoj
	git           => '/usr/bin/git'

};

$CFG->{revo_from} =  "Reta Vortaro <$CFG->{revo_mailaddr}>";
$CFG->{signature} = "--\nRevo-Servo $CFG->{revo_mailaddr}\n"
		."retposhta servo por redaktantoj de Reta Vortaro.\n";


	# dosierujoj
$CFG->{dict_base} =  "$CFG->{dict_home}/dict"; # xml, dok, dtd
$CFG->{tmp}       =  "$CFG->{dict_base}/tmp";
$CFG->{log_dir}   =  "$CFG->{dict_base}/log";

$CFG->{mail_send} =  "$CFG->{tmp}/mailsend";

$CFG->{rez_dir}   =  "$CFG->{dict_base}/rez";
$CFG->{xml_dir}   =  "$CFG->{dict_base}/xml";
	#$git_repo     => $ENV{"GIT_REPO_REVO"} || "revo-fonto";
$CFG->{git_dir}   =  "$CFG->{dict_base}/revo-fonto";

$CFG->{editor_file} =  "$CFG->{dict_etc}/redaktantoj.json"; #"$CFG->{dict_etc}/voko.redaktantoj";

# agordo de servilo-konekto
if ($ENV{REVO_HOST} eq "araneo" || $ENV{REVO_HOST} eq "cetonio:8080") {
	# ene de docker-medio ni uzas nur HTTP
	$CFG->{submeto_url} = "http://$ENV{REVO_HOST}";
	$CFG->{netloc} = $ENV{REVO_HOST};
} elsif ($ENV{REVO_HOST}) {
	# uzu HTTPS kun ekstera servilo
	$CFG->{submeto_url} = "https://$ENV{REVO_HOST}";
	$CFG->{netloc} = $ENV{REVO_HOST}.':443';
}

if ($ENV{ADM_URL} && $ENV{REVO_HOST} !~ m/reta-?vortaro\.de/x) {
	$CFG->{submeto_url} .= $ENV{ADM_URL}.'/submeto.pl';
	$CFG->{realm} = 'submetoj';
} else {
	$CFG->{submeto_url} .= '/cgi-bin/admin/submeto.pl';
}

# preparu protokolon
our $LOG = Log::Dispatch->new(
	outputs => [
		#[ 'File',   min_level => 'debug', filename => 'logfile' ],
		[ 'Screen', min_level => $CFG->{loglevel} ],
	],
);

###
$LOG->debug("realm: $CFG->{realm}\n");
$LOG->debug("netloc: $CFG->{netloc}\n");
$LOG->debug("ADM_USER: $ENV{'ADM_USER'}\n");
#$LOG->debug("netloc: ".substr($CFG->{netloc},0,10)."...\n");
#$LOG->debug("ADM_USER: ".substr($ENV{'ADM_USER'},0,3)."...\n");

# preparu UserAgent
our $UA = LWP::UserAgent->new();
$UA->agent('Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:36.0) Gecko/20100101 Firefox/36.0');
$UA->credentials( # vd https://perlmaven.com/lwp-useragent-and-basic-authentication
	$CFG->{netloc},$CFG->{realm},
	$ENV{'ADM_USER'} => $ENV{'ADM_PASSWORD'}
);

################ la precipa masho de la programo ##############

our $CTX = {
	editor     => undef, # aktuala submetinto
	editors    => undef, # listo de registritaj
	article_id => '',
	shangho    => '',
	mail_send_sep => '',
};

# tiel ni povas testi sub-funkciojn de ekstere:
MAIN() unless caller(); sub MAIN {

	# certigu, ke provizoraj dosierujoj ekzistu
	mkdir($CFG->{tmp}); 
	mkdir($CFG->{log_dir});
	mkdir($CFG->{rez_dir}); 

	# legu redaktantojn el JSON-dosiero kaj transformu al HASH por 
	# trovi ilin facile laŭ numero (red_id)
	$CTX->{editors} = process::read_json_file($CFG->{editor_file});

	process::write_file(">:encoding(utf-8)", $CFG->{mail_send},"[\n"); 

	my @submetoj = submeto_listo();
	#$LOG->info(Dumper(@submetoj));

	$LOG->info("Trovitaj novaj submetoj: ".($#submetoj+1)."\n");
	exit unless (@submetoj && $#submetoj >= 0 && $submetoj[0]->{id});

	foreach my $subm (@submetoj) {

		$LOG->info($CFG->{separator});

		$LOG->debug(join(',',keys %$subm)."\n");
		$LOG->debug(join(',',values %$subm)."\n");
		#$LOG->debug(encode('utf-8',join(',',values %$subm))."\n");

		# eligu iom da informo pri la submeto
		$LOG->info(
			"id:".$subm->{"id"}."\n".
			"date:",$subm->{"time"}."\n".
			"desc:",$subm->{"desc"}."\n"); #encode('utf-8',$subm->{"desc"})."\n");


		# preparu por la nova mesagho
		$CTX->{editor} = undef;
		$CTX->{article_id} = '';

		my %subm_detaloj = pluku_submeton($subm->{'id'});
		unless (%subm_detaloj) {
			next;
		}

		$LOG->debug("subm_det: ".join(',',keys %subm_detaloj)."; xml: ".length($subm_detaloj{xml})." bitokoj\n");

		# analizu la enhavon de la mesagho
		process_subm($subm,\%subm_detaloj);
	}

	process::write_file(">>:encoding(utf-8)",$CFG->{mail_send},"\n]\n");

	$LOG->info($CFG->{separator});
	#git_push();
	my ($lg,$err) = process::git_cmd("$CFG->{git} push origin master");

	if ($err =~ m/fatal/ || $err =~ m/error/) {
		# se okazas problemo puŝi la ŝanĝojn, ne sendu raportojn, sed tuj finu
		# kun eraro-stato
		# PLIBONIGU: tiuokaze ni fakte ankaŭ devus remeti la staton de submetoj de 'trakt' al 'nov'!
		# por ebligi retrakton venonantan fojon...
		exit 1;
	}

	$LOG->info($CFG->{separator});

	# sendu raportojn
	# provizore jam nun konektu al SMTP, por trovi eraron en ->auth
	#$IO::Socket::SSL::DEBUG=3;
	if (-s $CFG->{mail_send} > 10) {
		my $mailer = mailsender::smtp_connect;
		send_reports($mailer);
		mailsender::smtp_quit($mailer);
	}

	#send_newarts_report();
	$LOG->info($CFG->{separator});

	if (-s $CFG->{mail_send} > 10) {
		my $filename = "mail_sent_".timestamp();    
		$LOG->info("ŝovas $CFG->{mail_send} al $CFG->{log_dir}/$filename\n");
		rename($CFG->{mail_send},$CFG->{log_dir}."/$filename");
	}  

	$LOG->info($CFG->{separator});

	exit;

} # MAIN

###################### analizado de la mesaghoj ################

sub process_subm {
    my $subm = shift;
	my $detaloj = shift;

	unless ($subm->{desc}) {
		$LOG->warn("Mankas priskribo en: ".$subm->{id}."\n");
		return;
	}
   
    # kontrolu, ĉu temas pri registrita redaktoro 
	$CTX->{editor} = is_editor($detaloj->{redaktanto});
    unless ($CTX->{editor}) 
    { 
		$LOG->warn("Ne registrita redaktanto: ".$detaloj->{redaktanto}."\n");
		return;
	}    
	
	# traktu priskribon redakt/aldon..., XML...
	if ($subm->{cmd} eq 'redakto') {
		return cmd_redakt($subm, $detaloj);

	} elsif ($subm->{cmd} eq 'aldono') {
		return cmd_aldon($subm, $detaloj);
	};
}

sub is_editor {
    my $retadreso = shift;

	# se ne troviĝis, trairu la liston kaj kalkulu dume la Sha-ojn
	for my $ed (@$CTX->{editors}) {
		for my $ra (@{$ed->{retadr}}) {
			return $ed if ($retadreso eq $ra);
		}
	}
	# ne trovita
	return;
}



######################### respondoj al sendintoj ###################

sub report {
    my ($subm, $detaloj) = @_;
    
	#$detaloj->{mesagho} = encode('utf-8',$detaloj->{mesagho});
    $LOG->info($detaloj->{mesagho}."\n");

	$detaloj->{subm_id} = $subm->{id};
    $detaloj->{senddato} = $subm->{time};
	#write_json_file(">","$CFG->{rez_dir}/$subm->{id}", $detaloj);
	#submeto_rezulto($subm->{id},$detaloj);

	$detaloj->{sendinto} = $CTX->{editor}->{red_nomo}." <".$CTX->{editor}->{retadr}[0].">";
	process::write_json_file(">>:encoding(utf-8)",$CFG->{mail_send}, $detaloj, $CTX->{mail_send_sep});
	$CTX->{mail_send_sep} = ',';

	return;
}

sub send_reports {
	my $mailer = shift;

    my %reports = ();
    my %dosieroj = ();
    my $mail_addr;

	$LOG->info("sendas raportojn al redaktintoj...\n");

	# kolektu raportojn laŭ retadreso
	my $reps = process::read_json_file($CFG->{mail_send});
	for my $rep (@$reps) {
		
		# aktualigu submeton
		submeto_rezulto($rep->{subm_id},$rep);

		# alordigu raporton al la sendinto de la redakto
		if ($rep->{sendinto}) {
			$mail_addr = $rep->{sendinto};
			
			# chu dosierojn sendu?
			if ($rep->{dosiero}) {
				push(@{$dosieroj{$mail_addr}},[$rep->{dosiero},$rep->{artikolo}])
			}
			push(@{$reports{$mail_addr}},$rep);

		} else {
			$LOG->warn("Ne povis elpreni sendinton el $_\n");
			next;
		}
	}

	# print "dosieroj: ",Dumper(%dosieroj) if ($debug);

	# forsendu la raportojn
	while (my ($maddr,$report) = each %reports) {

		my $message = "Saluton!\nJen raporto pri via(j) sendita(j) artikolo(j).\n\n";
		for (@$report) {
			$message .= $CFG->{separator}.process::rep_str($_);
		}
		$message .= $CFG->{separator}."\n\n".$CFG->{signature};
		
		my $to = $maddr;
		$to =~ s{
			.*
			<
			([a-z\.\_\-@]+)
			>
			.*
		}{$1}x;

		my $mail_handle = build MIME::Entity(Type=>"multipart/mixed",
						From=>$CFG->{revo_from},
						To=>$to,
						Subject=>"$CFG->{revoservo} - raporto");
		
		$mail_handle->attach(Type=>"text/plain",
				Encoding=>"quoted-printable",
				Data=>$message);
		
		# alpendigu dosierojn
		$LOG->debug("dosieroj{maddr}: ");
		$LOG->debug(Dumper(@{$dosieroj{$maddr}}));

		for my $dos (@{$dosieroj{$maddr}}) {
			my $file = $dos->[0];
			my $art_id = $dos->[1];
			my $marko;

			if ($art_id) {
				if ( $art_id =~ m{
					^\044       # $
					([^\044]+)
					\044        # $
				$}x ) {
					$art_id = $1;
					if ( $art_id =~ m{
						^Id:\s+     # Id:
						([^ ,\.]+   # dosiernomo
						\.xml),v    # fino
					}x ) { 
						$marko = $1;
					};

				} else {
					$marko=$art_id;
				}
			} else { $art_id = $file; $marko=$file; }
				
			$LOG->debug("attach: $file\n");
			if (-e $file) {
				$mail_handle->attach(Path=>$file,
						Type=>'text/plain',
						Encoding=>'quoted-printable',
						Disposition=>'attachment',
						Filename=>$marko,
						Description=>$art_id);
			}
		}
		
		# forsendu
		unless (mailsender::smtp_send($mailer,$CFG->{revo_from},$to,$mail_handle)) {
			$LOG->warn("Ne povas forsendi retpoŝtan raporton!\n");
			next;
		}
	}

	#mailsender::smtp_quit($mailer);
	return;
}

###################### komandoj kaj helpfunkcioj ##############

# redakto de jam ekzistanta artikolo
sub cmd_redakt {
    my ($subm,$detaloj) = @_;
	my $fname = "$CFG->{xml_dir}/".$subm->{fname}.".xml";
	process::write_file(">:encoding(utf-8)",$fname,$detaloj->{xml});

    #$CTX->{shangho} = $shangh; # memoru por poste
    #$CTX->{shangho} =~ s/[\200-\377]/?/g; # forigu ne-askiajn signojn
	$LOG->debug("redakto: ".$subm->{desc}."\n"); # encode('utf-8',$subm->{desc})."\n");

    # pri kiu artikolo temas, trovighas en <art mrk="...">
	my $CTX->{article_id} = process::get_art_id($fname);
    my $art = extract_article($subm,$CTX->{article_id});

    unless ($art =~ /^[a-z0-9_]+$/ix) {
		report($subm,
			{
				"rezulto"=>"eraro",
				"mesagho" => "Ne valida artikolmarko $art. Ĝi povas enhavi nur "
	      				."literojn, ciferojn kaj substrekon.",
				"dosiero" => $fname,
				"artikolo" => $CTX->{article_id}
			});
		return;
    }

    # kontroli la sintakson kaj arĥivi
    if (check_xml($subm,$fname,$CTX->{article_id},0)) {
		return checkin($subm,$art,$CTX->{article_id},$fname);
    }
	return;
}

# nova artikolo
sub cmd_aldon {
    my ($subm, $detaloj) = @_;

    # kio estu la nomo de la nova artikolo
	my $art = process::trim($subm->{fname}); 
	my $fname = "$CFG->{xml_dir}/".$subm->{fname}.".xml";
	process::write_file(">:encoding(utf-8)",$fname,$detaloj->{xml});
   
    unless ($art =~ /^[a-z0-9_]+$/sx) {
		report($subm, { 
			"rezulto"=>"eraro",
			"mesagho" => "Ne valida nomo por artikolo. \"$art\".\n"
	       	  			."Ĝi konsistu nur el minuskloj, substrekoj kaj ciferoj.",
			"dosiero" => $fname,
			"artikolo" => $art
		});
		return;
    }
    $LOG->info("nova artikolo: $art\n");

    # bezonighas article_id en kazo de eraro
    $CTX->{article_id} = "\044Id: $art.xml,v\044";

    # kontrolu, ĉu la dosiernomo estas ankoraŭ uzebla
	my $xml_file = "$CFG->{git_dir}/revo/$art.xml";
    if (-e "$xml_file") {
		report($subm, {
			"rezulto"=>"eraro",
			"mesagho" => "Artikolo kun la dosiernomo $art.xml jam ekzistas\n"
			   			."Bv. elekti alian nomon por la nova artikolo.",
			"dosiero" => $fname,
			"artikolo" => $CTX->{article_id}
		});
		return;
    }

    # kontroli la sintakson kaj arĥivi
    if (check_xml($subm,$fname,$CTX->{article_id},1)) {
		return checkinnew($subm,$art,$CTX->{article_id},$fname);
    }
	return;
}

sub check_xml {
	my ($subm,$fname,$article_id,$nova) = @_;

	my $err = process::checkxml($subm->{id},$fname,$nova);

	if ($err) {
		$err .= "\nkunteksto:\n".process::xml_context($err,"$fname");
		$LOG->info("XML-eraroj:\n$err");

		report($subm, {
			"rezulto" => "eraro",
			"mesagho" => "La XML-dosiero enhavas la sekvajn "
						."sintakserarojn:\n$err",
			"artikolo" => $article_id,
			"dosiero" => $fname
		});
		return;
    } else {
		$LOG->debug("XML: en ordo\n");
		return 1;
    }
}

sub checkin {
    my ($subm,$art,$id,$fname) = @_;
	my $shangho = $subm->{desc}; # encode('utf-8',$subm->{desc});

    # kontrolu chu ekzistas shangh-priskribo
    unless ($shangho) {
	  	report($subm, {
		  	"rezulto" => "eraro",
		  	"mesagho" => "Vi forgesis indiki, kiujn ŝanĝojn vi faris "
	    				."en la dosiero.",
			"artikolo" => $id,
			"dosiero" => $fname
	  	});
      	return;
    } 
    $LOG->info("ŝanĝoj: ".$shangho."\n");

    # skribu la shanghojn en dosieron
    my $edtr = $CTX->{editor}->{red_nomo};
    #$edtr =~ s/\s*<(.*?)>\s*//;

	process::write_file(">:encoding(utf-8)","$CFG->{tmp}/shanghoj.msg","$edtr: $subm->{desc}");

    # kontrolu, chu la artikolo bazighas sur la aktuala versio
	my $repo_art_file = "$CFG->{git_dir}/revo/$art.xml";

	unless (-e $repo_art_file) {
		report($subm, {
			"rezulto" => "eraro",
			"mesagho" => "En la arĥivo ne troviĝis la artikolo\n"
	       		 		."kiun vi redaktis ($art), ĉu temas pri nova?\n"
	       				."Se jes, sendu kun indiko \"aldono:\". Se ne, bv.\n"
						."serĉu la artikolon kun la ĝusta nomo kaj versio en la TTT-ejo. "
	       				."($CFG->{revo_url})",
			"shangho" => $shangho,
			"dosiero" => $fname,
			"artikolo" => $id
		});
		return;
	}

    my $ark_id = process::get_art_id($repo_art_file);

    # eble tro strikta: if ($ark_id ne $id) {
 	if (substr($ark_id,0,-19) ne substr($id,0,-19)) {
		# versiokonflikto
		report($subm, {
			"rezulto" => "eraro",
			"mesagho" => "La de vi sendita artikolo\n"
	       		 		."ne baziĝas sur la aktuala arkiva versio\n"
	       				."($ark_id)\n"
	       				."Bonvolu preni aktualan version el la TTT-ejo. "
	       				."($CFG->{xml_source_url}/$art.xml)",
			"shangho" => $shangho,
			"dosiero" => $fname,
			"artikolo" => $id
		});
		return;
    }

	# checkin in Git
	$LOG->info("cp ${fname} $repo_art_file\n");
    copy($fname,$repo_art_file);

	my $ok = checkin_git($subm,$repo_art_file,$edtr,$id);

	unlink("$CFG->{tmp}/shanghoj.msg");

	return $ok;
}


sub checkin_git {
	my ($subm,$xmlfile,$edtr,$id) = @_;
	my $shangho = encode('utf-8',$subm->{desc});

	process::incr_ver("$xmlfile","$CFG->{tmp}/shanghoj.msg");

	my ($log1,$err1) = process::git_cmd("$CFG->{git} add $xmlfile");
	my ($log2,$err2) = process::git_cmd("$CFG->{git} commit -F $CFG->{tmp}/shanghoj.msg");

	# chu 'commit' sukcesis?

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
    if ( $log2 =~ m{
		nothing\s
		to\s
		commit
	}sx ) {
		report("ERARO   : La sendita artikolo shajne ne diferencas de "
			."la aktuala versio.");
		return;
    } elsif ($err2 !~ /^\s*$/sx) {
		report($subm, {
			"rezulto" => "eraro",
			"mesagho" => "Eraro dum arkivado de la nova artikolversio:\n"
						."$log1\n$log2\n$err1\n$err2\n",
			"shangho" => $shangho,
			"artikolo" => $id,
			"dosiero" => $xmlfile
		});
		return;
    }

    # raportu sukceson 
    report($subm, {
		"rezulto" => "konfirmo",
 		"artikolo" => $id,
		"shangho" => $shangho,
		"mesagho" => $log2
	});
	return 1;
}

sub checkinnew {
    my ($subm,$art,$id,$fname) = @_;
	my $shangho = encode('utf-8',$subm->{desc});

    $shangho = "nova artikolo";
    $LOG->info("shanghoj: $shangho\n");

    # skribu la shanghojn en dosieron
    my $edtr = $CTX->{editor}->{red_nomo};
    #$edtr =~ s/\s*<(.*?)>\s*//;

    process::write_file(">:encoding(utf-8)","$CFG->{tmp}/shanghoj.msg","$edtr: $shangho");

	my $repo_art_file = "$CFG->{git_dir}/revo/$art.xml";

	# checkin in Git
    $LOG->debug("cp $fname $repo_art_file\n");
    copy($fname,$repo_art_file);

	my $ok = checkinnew_git($subm,$repo_art_file,$edtr,$id);

	unlink("$CFG->{tmp}/shanghoj.msg");

	return $ok;
}


sub checkinnew_git {
	my ($subm,$xmlfile,$edtr,$id) = @_;

	process::init_ver("$xmlfile","$CFG->{tmp}/shanghoj.msg");

	my ($log1,$err1) = process::git_cmd("$CFG->{git} add $xmlfile");
	my ($log2,$err2) = process::git_cmd("$CFG->{git} commit -F $CFG->{tmp}/shanghoj.msg");

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
    if ( $log2 =~ m{
		nothing\s
		to\s
		commit
	}sx ) {
		report("ERARO   : La sendita artikolo shajne ne diferencas de "
			."la aktuala versio.");
		return;
    } elsif ($err2 !~ /^\s*$/sx) {
		report($subm, {
			"rezulto" => "eraro",
			"mesagho" => "Eraro dum arkivado de la nova artikolversio:\n"
						."$log1\n$log2\n$err1\n$err2\n",
			"artikolo" => $id,
			"dosiero" => $xmlfile
		});
		return;
    }

    # raportu sukceson 
    report($subm, {
		"rezulto" => "konfirmo",
		"artikolo" => $id,
		"mesagho" => $log2
	});
	return 1;
}

sub extract_article {
    my ($subm,$id) = @_;
    # ekstraktu dosiernomon el $Id: ...
    unless ( $id =~ m{
		^\044Id:\s+  # Id:
		([^\ ,\.]+)  # dosiernomo
		\.xml,v\s+   # fino
		[0-9\.]+     # versio
	}x ) {
		report($subm, {
			"rezulto" => "eraro",
			"mesagho" => "Artikol-marko havas malĝustan sintakson",
			"artikolo" => $id
		});
		$LOG->warn("$id ne enhavas dosiernomon\n");
		return '???';
    } else {
		return $1;
    }
}



###################################################
# legado kaj aktualigado de submetoj en la servilo/datumbazo

sub submeto_listo {
	my $result = $UA->post($CFG->{submeto_url},[format=>'text']);

	if ($result->is_success) {
		my $csv = $result->decoded_content(); # decode('utf8', $result->content);
		return process::csv2arr($csv);
	} else {
		$LOG->error("Ne eblis preni liston de submetoj el $CFG->{submeto_url}.\n".$result->status_line."\n");
		#return 0;
		exit 1;
	}
}

sub pluku_submeton {
	my $id = shift;
	my ($redaktanto,$shangho,$xml);

	$LOG->info("submeto: $id\n");

	my $result = $UA->post($CFG->{submeto_url},[
		id=>$id, 
		state=>'trakt'
	]);

	if ($result->is_success) {
 		my @lines = split("\n",$result->decoded_content()); # decode('utf8', $result->content));

		$LOG->debug("first line:".$lines[0]."\n");
		# prenu redaktanton
		my ($key,$value) = split(':',shift @lines);
		if ($key eq 'From') {
			$redaktanto = process::trim($value);
		} else {
			$LOG->warn("Submeto ne enhavas redaktanton en la unua linio.\n");
			return 0;
		}
		while ($lines[0] =~ m/^\s*$/sx) {
			shift @lines;
		}
		$LOG->debug("next line:".$lines[0]."\n");

		# prenu komandon kaj ŝanĝon
		#my $line = shift @lines;
		#$line =~ m/^(redakto|aldono):\s*(.*)$/;
		#if ($1) {
		#	$cmd = $1;
		#	$shangho = $2;
		#} else {
		#	$LOG->warn("En la submeto ne troviĝis komando aŭ enestas nekonata komando.\n");
		#	return 0;
		#}
		#while (@lines[0] =~ m/\s*\n/) {
		#	shift @lines;
		#}

		# trovu la komencon de XML kaj kunkolektu ties liniojn
		if ($lines[0] =~ m/^\s*<\?xml/x) {
			$xml = join("\n",@lines);
		} else {
			$LOG->warn("En la submeto ne troviĝis XML-teksto.\n");
			return 0;
		}

		# redonu ĉion
		return (
			redaktanto => $redaktanto,
			xml => $xml);

	} else {
		$LOG->warn("Ne eblis preni submeton '$id'.\n".$result->status_line);
		return 0;
	}
}

sub submeto_rezulto {
	my ($subm_id,$detaloj) = @_;
	my $state;

	if ($detaloj->{rezulto} eq 'konfirmo') {
		$state = 'arkiv';
	} else {
		$state = 'erar';
	}
    # vd. https://www.perl.com/pub/2002/08/20/perlandlwp.html/
	#$LOG->info("Aktualigo de submeto ".$subm_id.", stat: $state [".decode('utf-8',$detaloj->{mesagho})."]\n");
	$LOG->info("Aktualigo de submeto ".$subm_id.", stat: $state [".$detaloj->{mesagho}."]\n");
	my $res = $UA->post($CFG->{submeto_url},
		[
			id => $subm_id, 
			state => $state,
			result => $detaloj->{mesagho} # encode('utf-8',$detaloj->{mesagho})
		],
		Content_Type => 'form-data'
	);
#		"Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8"
#		);

 	if (not $res->is_success) {
		$LOG->warn("Ne eblis aktualigi la rezulton de la submeto '".$subm_id."'\n".$res->status_line);
		return;
	} else {
		$LOG->info("Aktualigo rezulto: ".$res->content)
	}

	return;
}

# fino
1;