#!/usr/bin/perl

# prenas la redaktitajn artikolojn el loka
# dosierujo kreita per elŝutado de Github-gistoj
# kaj analizas, sintakse kontrolas
# kaj arkivas (per Git) ilin.
#
# voku:
#  processgist.pl

use warnings;

use MIME::Entity;
use Log::Dispatch;
use LWP::UserAgent;
use Encode;

use Data::Dumper;

use lib("/usr/local/bin");
use lib("./bin");
use process qw( trim );
use mailsender;


######################### agorda parto ##################

# kiom da informoj
#$verbose      = 1;
#$debug        = 1;
$loglevel = 'debug'; # info...
my $realm = 'reta-vortaro.de:443';

# baza agordo
if ($ENV{REVO_HOST} eq "araneo") {
	# ene de docker-medio ni uzas nur HTTP
	$submeto_url = "http://araneo/cgi-bin/admin/submeto.pl"
} elsif ($ENV{REVO_HOST}) {
	# uzu HTTPS kun eksterna servilo
	$submeto_url = "https://$ENV{REVO_HOST}/cgi-bin/admin/submeto.pl";
	$realm = $ENV{REVO_HOST}.':443';
} else {	
	# se SERVILO ne estas aparte difinita ni uzas reta-vortaro.de
  	$submeto_url = 'https://reta-vortaro.de/cgi-bin/admin/submeto.pl';
}
#$afido_dir    = "/var/afido"; # tmp, log
$dict_home    = $ENV{"HOME"}; # por testi: $ENV{'PWD'};
$dict_base    = "$dict_home/dict"; # xml, dok, dtd
$dict_etc     = $ENV{"HOME"}."/etc"; #"/run/secrets"; # redaktantoj
#$vokomail_url = "http://www.reta-vortaro.de/cgi-bin/vokomail.pl";
$xml_source_url = 'https://github.com/revuloj/revo-fonto/blob/master/revo';
$revo_url     = 'http://purl.oclc.org/NET/voko/revo';
#$mail_folder  = "/var/spool/mail/tomocero";

$revoservo    = '[Revo-Servo]';
$revo_mailaddr= 'revo@reta-vortaro.de';
#$redaktilo_from= 'revo-servo@steloj.de';
$revo_from    = "Reta Vortaro <$revo_mailaddr>";
$signature    = "--\nRevo-Servo $revo_mailaddr\n"
    ."retposhta servo por redaktantoj de Reta Vortaro.\n";


# programoj
$git          = '/usr/bin/git';

# dosierujoj
$tmp          = "$dict_base/tmp";
$log_dir      = "$dict_base/log";

$mail_send    = "$tmp/mailsend";

$rez_dir      = "$dict_base/rez";
$xml_dir      = "$dict_base/xml";
#$git_repo     = $ENV{"GIT_REPO_REVO"} || "revo-fonto";
$git_dir      = "$dict_base/revo-fonto";

$editor_file  = "$dict_etc/redaktantoj.json"; #"$dict_etc/voko.redaktantoj";

$separator    = "=" x 80 . "\n";

# preparu protokolon
my $log = Log::Dispatch->new(
    outputs => [
        #[ 'File',   min_level => 'debug', filename => 'logfile' ],
        [ 'Screen', min_level => $loglevel ],
    ],
);

# preparu UserAgent
my $ua = LWP::UserAgent->new();
$ua->agent('Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:36.0) Gecko/20100101 Firefox/36.0');
$ua->credentials( # vd https://perlmaven.com/lwp-useragent-and-basic-authentication
    $realm,'Restricted Content',
    $ENV{'CGI_USER'} => $ENV{'CGI_PASSWORD'}
);

################ la precipa masho de la programo ##############

$editor     = '';
$article_id = '';
$shangho    = '';

# certigu, ke provizoraj dosierujoj ekzistu
mkdir($tmp); 
mkdir($log_dir);
mkdir($rez_dir); 


# legu redaktantoj el JSON-dosiero kaj transformu al HASH por 
# trovi ilin facile laŭ numero (red_id)
$editors=process::read_json_file($editor_file);

process::write_file(">", $mail_send,"[\n"); my $mail_send_sep = '';

my @submetoj = submeto_listo();
#$log->info(Dumper(@submetoj));

$log->info("Trovitaj novaj submetoj: ".($#submetoj+1)."\n");
exit unless (@submetoj && $#submetoj >= 0 && $submetoj[0]->{id});

foreach my $subm (@submetoj) {

    $log->info($separator);

	$log->debug(join(',',keys %$subm));
	$log->debug(encode('utf-8',join(',',values %$subm))."\n");

	# eligu iom da informo pri la submeto
	$log->info(
		"id:".$subm->{"id"}."\n".
		"date:",$subm->{"time"}."\n".
		"desc:",encode('utf-8',$subm->{"desc"})."\n");


    # preparu por la nova mesagho
    $editor = '';
    $shangho = '';
    $article_id = '';

	%subm_detaloj = pluku_submeton($subm->{'id'});
    unless (%subm_detaloj) {
		next;
    }

	$log->debug("subm_det: ".join(',',keys %subm_detaloj)."; xml: ".length($subm_detaloj{xml})." bitokoj\n");

    # analizu la enhavon de la mesagho
    process_subm($subm,\%subm_detaloj);	
}

process::write_file(">>",$mail_send,"\n]\n");

$log->info($separator);
#git_push();
my ($lg,$err) = process::git_cmd("$git push origin master");

if ($err =~ m/fatal/ || $err =~ m/error/) {
	# se okazas problemo puŝi la ŝanĝojn, ne sendu raportojn, sed tuj finu
	# kun eraro-stato
	# PLIBONIGU: tiuokaze ni fakte ankaŭ devus remeti la staton de submetoj de 'trakt' al 'nov'!
	# por ebligi retrakton venonantan fojon...
	exit 1;
}

$log->info($separator);

# sendu raportojn
# provizore jam nun konektu al SMTP, por trovi eraron en ->auth
#$IO::Socket::SSL::DEBUG=3;
if (-s $mail_send > 10) {
	my $mailer = mailsender::smtp_connect;
	send_reports($mailer);
	mailsender::smtp_quit($mailer);
}

#send_newarts_report();
$log->info($separator);

if (-s $mail_send > 10) {
	$filename = "mail_sent_".`date +%Y%m%d_%H%M%S`;    
    $log->info("ŝovas $mail_send al $log_dir/$filename\n");
    `mv $mail_send $log_dir/$filename`;
}  

$log->info($separator);

exit;


###################### analizado de la mesaghoj ################

sub process_subm {
    my $subm = shift;
	my $detaloj = shift;

	unless ($subm->{desc}) {
		$log->warn("Mankas priskribo en: ".$subm->{id}."\n");
		return;
	}
   
    # kontrolu, ĉu temas pri registrita redaktoro 
	$editor = is_editor($detaloj->{redaktanto});
    unless ($editor) 
    { 
		$log->warn("Ne registrita redaktanto: ".$detaloj->{redaktanto}."\n");
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
	for $ed (@$editors) {
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
    
    $log->info($detaloj->{mesagho}."\n");

	$detaloj->{subm_id} = $subm->{id};
    $detaloj->{senddato} = $subm->{time};
	#write_json_file(">","$rez_dir/$subm->{id}", $detaloj);
	#submeto_rezulto($subm->{id},$detaloj);

	$detaloj->{sendinto} = $editor->{red_nomo}." <".$editor->{retadr}[0].">";
	process::write_json_file(">>",$mail_send, $detaloj, $mail_send_sep);
	$mail_send_sep = ',';
}

sub send_reports {
	my $mailer = shift;

    my %reports = ();
    my %dosieroj = ();
    my $mail_addr;

	$log->info("sendas raportojn al redaktintoj...\n");

	# kolektu raportojn laŭ retadreso
	my $reps = process::read_json_file($mail_send);
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
			$log->warn("Ne povis elpreni sendinton el $_\n");
			next;
		}
	}

	# print "dosieroj: ",Dumper(%dosieroj) if ($debug);

	# forsendu la raportojn
	while (my ($maddr,$report) = each %reports) {

		$message = "Saluton!\nJen raporto pri via(j) sendita(j) artikolo(j).\n\n";
		for (@$report) {
			$message .= $separator.process::rep_str($_);
		}
		$message .= $separator."\n\n".$signature;
		
		my $to = $maddr;
		$to =~ s/.*<([a-z\.\_\-@]+)>.*/$1/;

		$mail_handle = build MIME::Entity(Type=>"multipart/mixed",
						From=>$revo_from,
						To=>$to,
						Subject=>"$revoservo - raporto");
		
		$mail_handle->attach(Type=>"text/plain",
				Encoding=>"quoted-printable",
				Data=>$message);
		
		# alpendigu dosierojn
		$log->debug("dosieroj{maddr}: ".Dumper(@{$dosieroj{$maddr}}));
		for $dos (@{$dosieroj{$maddr}}) {
			$file = $dos->[0];
			$art_id = $dos->[1];

			if ($art_id) {
				if ($art_id =~ /^\044([^\044]+)\044$/) {
					$art_id = $1;
					$art_id =~ /^Id: ([^ ,\.]+\.xml),v/;
					$marko = $1;
				} else {
					$marko=$art_id;
				}
			} else { $art_id = $file; $marko=$file; }
				
			$log->debug("attach: $file\n");
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
		unless (mailsender::smtp_send($mailer,$revo_from,$to,$mail_handle)) {
			$log->warn("Ne povas forsendi retpoŝtan raporton!\n");
			next;
		}
	}

	#mailsender::smtp_quit($mailer);
}

###################### komandoj kaj helpfunkcioj ##############

# redakto de jam ekzistanta artikolo
sub cmd_redakt {
    my ($subm,$detaloj) = @_;
	my $fname = "$xml_dir/".$subm->{fname}.".xml";
	process::write_file(">",$fname,$detaloj->{xml});

    #$shangho = $shangh; # memoru por poste
    #$shangho =~ s/[\200-\377]/?/g; # forigu ne-askiajn signojn
	$log->debug("redakto: ".encode('utf-8',$subm->{desc})."\n");

    # pri kiu artikolo temas, trovighas en <art mrk="...">
	my $article_id = process::get_art_id($fname);
    my $art = extract_article($subm,$article_id);

    unless ($art =~ /^[a-z0-9_]+$/i) {
		report($subm,
			{
				"rezulto"=>"eraro",
				"mesagho" => "Ne valida artikolmarko $art. Ĝi povas enhavi nur "
	      				."literojn, ciferojn kaj substrekon.",
				"dosiero" => $fname,
				"artikolo" => $article_id
			});
		return;
    }

    # kontroli la sintakson kaj arĥivi
    if (check_xml($subm,$fname,$article_id,0)) {
		return checkin($subm,$art,$article_id,$fname);
    }
	return;
}

# nova artikolo
sub cmd_aldon {
    my ($subm, $detaloj) = @_;

    # kio estu la nomo de la nova artikolo
	my $art = process::trim($subm->{fname}); 
	my $fname = "$xml_dir/".$subm->{fname}.".xml";
	process::write_file(">",$fname,$detaloj->{xml});
   
    unless ($art =~ /^[a-z0-9_]+$/s) {
		report($subm, { 
			"rezulto"=>"eraro",
			"mesagho" => "Ne valida nomo por artikolo. \"$art\".\n"
	       	  			."Ĝi konsistu nur el minuskloj, substrekoj kaj ciferoj.",
			"dosiero" => $fname,
			"artikolo" => $art
		});
		return;
    }
    my $shangho = $art; # memoru por poste
    $log->info("nova artikolo: $art\n");

    # bezonighas article_id en kazo de eraro
    $article_id = "\044Id: $art.xml,v\044";

    # kontrolu, ĉu la dosiernomo estas ankoraŭ uzebla
	$xml_file = "$git_dir/revo/$art.xml";
    if (-e "$xml_file") {
		report($subm, {
			"rezulto"=>"eraro",
			"mesagho" => "Artikolo kun la dosiernomo $art.xml jam ekzistas\n"
			   			."Bv. elekti alian nomon por la nova artikolo.",
			"dosiero" => $fname,
			"artikolo" => $article_id
		});
		return;
    }

    # kontroli la sintakson kaj arĥivi
    if (check_xml($subm,$fname,$article_id,1)) {
		return checkinnew($subm,$art,$article_id,$fname);
    }
	return;
}

sub check_xml {
	my ($subm,$fname,$article_id,$nova) = @_;

	my $err = process::checkxml($subm->{id},$fname,$nova);

	if ($err) {
		$err .= "\nkunteksto:\n".process::xml_context($err,"$fname");
		$log->info("XML-eraroj:\n$err");

		report($subm, {
			"rezulto" => "eraro",
			"mesagho" => "La XML-dosiero enhavas la sekvajn "
						."sintakserarojn:\n$err",
			"artikolo" => $article_id,
			"dosiero" => $fname
		});
		return;
    } else {
		$log->debug("XML: en ordo\n");
		return 1;
    }
}

sub checkin {
    my ($subm,$art,$id,$fname) = @_;
	my $shangho = $subm->{desc};

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
    $log->info("ŝanĝoj: ".encode('utf-8',$subm->{desc})."\n");

    # skribu la shanghojn en dosieron
    my $edtr = $editor->{red_nomo};
    #$edtr =~ s/\s*<(.*?)>\s*//;

	process::write_file(">","$tmp/shanghoj.msg","$edtr: $subm->{desc}");

    # kontrolu, chu la artikolo bazighas sur la aktuala versio
	my $repo_art_file = "$git_dir/revo/$art.xml";

	unless (-e $repo_art_file) {
		report($subm, {
			"rezulto" => "eraro",
			"mesagho" => "En la arĥivo ne troviĝis la artikolo\n"
	       		 		."kiun vi redaktis ($art), ĉu temas pri nova?\n"
	       				."Se jes, sendu kun indiko \"aldono:\". Se ne, bv.\n"
						."serĉu la artikolon kun la ĝusta nomo kaj versio en la TTT-ejo. "
	       				."($revo_url)",
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
	       				."($xml_source_url/$art.xml)",
			"shangho" => $shangho,
			"dosiero" => $fname,
			"artikolo" => $id
		});
		return;
    }

	# checkin in Git
	$log->info("cp ${fname} $repo_art_file\n");
    `cp ${fname} $repo_art_file`;

	my $ok = checkin_git($subm,$repo_art_file,$edtr,$id);

	unlink("$tmp/shanghoj.msg");

	return $ok;
}


sub checkin_git {
	my ($subm,$xmlfile,$edtr,$id) = @_;
	my $shangho = $subm->{desc};

	process::incr_ver("$xmlfile","$tmp/shanghoj.msg");

	my ($log1,$err1) = process::git_cmd("$git add $xmlfile");
	my ($log2,$err2) = process::git_cmd("$git commit -F $tmp/shanghoj.msg");

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
    if ($log2 =~ /nothing\sto\scommit/s) {
		report("ERARO   : La sendita artikolo shajne ne diferencas de "
			."la aktuala versio.");
		return;
    } elsif ($err2 !~ /^\s*$/s) {
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
	my $shangho = $subm->{desc};

    $shangho = "nova artikolo";
    $log->info("shanghoj: $shangho\n");

    # skribu la shanghojn en dosieron
    my $edtr = $editor->{red_nomo};
    #$edtr =~ s/\s*<(.*?)>\s*//;

    process::write_file(">","$tmp/shanghoj.msg","$edtr: $shangho");

	my $repo_art_file = "$git_dir/revo/$art.xml";

	# checkin in Git
    $log->debug("cp $fname $repo_art_file\n");
    `cp $fname $repo_art_file`;

	my $ok = checkinnew_git($subm,$repo_art_file,$edtr,$id);

	unlink("$tmp/shanghoj.msg");

	return $ok;
}


sub checkinnew_git {
	my ($subm,$xmlfile,$edtr,$id) = @_;

	process::init_ver("$xmlfile","$tmp/shanghoj.msg");

	($log1,$err1) = process::git_cmd("$git add $xmlfile");
	($log2,$err2) = process::git_cmd("$git commit -F $tmp/shanghoj.msg");

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
    if ($log2 =~ /nothing\sto\scommit/s) {
		report("ERARO   : La sendita artikolo shajne ne diferencas de "
			."la aktuala versio.");
		return;
    } elsif ($err2 !~ /^\s*$/s) {
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
    unless ($id =~ /^\044Id: ([^ ,\.]+)\.xml,v\s+[0-9\.]+/) {
		report($subm, {
			"rezulto" => "eraro",
			"mesagho" => "Artikol-marko havas malĝustan sintakson",
			"artikolo" => $id
		});
		$log->warn("$id ne enhavas dosiernomon\n");
		return '???';
    } else {
		return $1;
    }
}



###################################################
# legado kaj aktualigado de submetoj en la servilo/datumbazo

sub submeto_listo {
	my @records;
	my $result = $ua->post($submeto_url,[format=>'text']);

	if ($result->is_success) {
		my $csv = decode('utf8', $result->content);
		return process::csv2arr($csv);
	} else {
		$log->error("Ne eblis preni liston de submetoj el $submeto_url.\n".$result->status_line."\n");
		#return 0;
		exit 1;
	}
}

sub pluku_submeton {
	my $id = shift;
	my ($redaktanto,$cmd,$shangho,$xml);

	$log->info("submeto: $id\n");

	my $result = $ua->post($submeto_url,[
		id=>$id, 
		state=>'trakt'
	]);

	if ($result->is_success) {
 		my @lines = split("\n",$result->content);

		$log->debug("first line:".$lines[0]."\n");
		# prenu redaktanton
		my ($key,$value) = split(':',shift @lines);
		if ($key eq 'From') {
			$redaktanto = process::trim($value);
		} else {
			$log->warn("Submeto ne enhavas redaktanton en la unua linio.\n");
			return 0;
		}
		while ($lines[0] =~ m/^\s*$/s) {
			shift @lines;
		}
		$log->debug("next line:".$lines[0]."\n");

		# prenu komandon kaj ŝanĝon
		#my $line = shift @lines;
		#$line =~ m/^(redakto|aldono):\s*(.*)$/;
		#if ($1) {
		#	$cmd = $1;
		#	$shangho = $2;
		#} else {
		#	$log->warn("En la submeto ne troviĝis komando aŭ enestas nekonata komando.\n");
		#	return 0;
		#}
		#while (@lines[0] =~ m/\s*\n/) {
		#	shift @lines;
		#}

		# trovu la komencon de XML kaj kunkolektu ties liniojn
		if ($lines[0] =~ m/^\s*<\?xml/) {
			$xml = join("\n",@lines);
		} else {
			$log->warn("En la submeto ne troviĝis XML-teksto.\n");
			return 0;
		}

		# redonu ĉion
		return (
			redaktanto => $redaktanto,
			xml => $xml);

	} else {
		$log->warn("Ne eblis preni submeton '$id'.\n".$result->status_line);
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
	$log->info("Aktualigo de submeto ".$subm_id.", stat: $state [".$detaloj->{mesagho}."]\n");
	my $res = $ua->post($submeto_url,
		[
			id => $subm_id, 
			state => $state,
			result => $detaloj->{mesagho}
		]);

 	if (not $res->is_success) {
		$log->warn("Ne eblis aktualigi la rezulton de la submeto '".$subm_id."'\n".$res->status_line);
		return;		
	} else {
		$log->info("Aktualigo rezulto: ".$res->content)
	}
}	


