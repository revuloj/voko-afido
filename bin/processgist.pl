#!/usr/bin/perl

# prenas la redaktitajn artikolojn el loka
# dosierujo kreita per elŝutado de Github-gistoj
# kaj analizas, sintakse kontrolas
# kaj arkivas (per Git) ilin.
#
# voku:
#  processgist.pl

use warnings;

use JSON;
use MIME::Entity;
use Digest::SHA qw(hmac_sha256_hex sha1_hex);
use experimental 'smartmatch';

use lib("/usr/local/bin");
#use lib("./bin");
use mailsender;

use Data::Dumper;

######################### agorda parto ##################

# kiom da informoj
$verbose      = 1;
$debug        = 1;

# FARENDA: legu tiujn el /docker swarm config/
# baza agordo
#$afido_dir    = "/var/afido"; # tmp, log
$dict_home    = $ENV{"HOME"}; # por testi: $ENV{'PWD'};
$dict_base    = "$dict_home/dict"; # xml, dok, dtd
$dict_etc     = $ENV{"HOME"}."/etc"; #"/run/secrets"; # redaktantoj
$vokomail_url = "http://www.reta-vortaro.de/cgi-bin/vokomail.pl";
$revo_url     = "http://purl.oclc.org/NET/voko/revo";
#$mail_folder  = "/var/spool/mail/tomocero";

# FARENDA: legu tiujn el sekreto(j)(?)
$revoservo    = '[Revo-Servo]';
$revo_mailaddr= 'revo@reta-vortaro.de';
#$redaktilo_from= 'revo-servo@steloj.de';
#$revolist     = 'wolfram';
$revo_from    = "Reta Vortaro <$revo_mailaddr>";
$signature    = "--\nRevo-Servo $revo_mailaddr\n"
    ."retposhta servo por redaktantoj de Reta Vortaro.\n";

$sigelilo_file = "/run/secrets/voko-afido.sigelilo";

# programoj
$xmlcheck     = '/usr/bin/rxp -V -s';
$git          = '/usr/bin/git';

# -t ne subtenata de ssmtp
#$sendmail     = '/usr/lib/sendmail -t -i';
#$sendmail     = '/usr/lib/sendmail -i';

# dosierujoj
$tmp          = "$dict_base/tmp";
$log_dir      = "$dict_base/log";
#$dtd_dir      = "$dict_base/dtd";

#$mail_error   = "$tmp/mailerr";
$mail_send    = "$tmp/mailsend";
$xml_temp     = "$tmp/xml";
#$dtd_temp     = "$tmp/dtd";

#$prc_gist     = "$log_dir/prcgist";

$gist_dir     = "$dict_base/gists";
$rez_dir      = "$dict_base/rez";
$json_dir     = "$dict_base/json";
$xml_dir      = "$dict_base/xml";
$git_repo     = $ENV{"GIT_REPO_REVO"} || "revo-fonto";
$git_dir      = "$dict_base/revo-fonto";
#$dok_dir      = "$dict_base/dok";

$editor_file  = "$dict_etc/redaktantoj.json"; #"$dict_etc/voko.redaktantoj";

# diversaj
#$possible_keys= 'komando|teksto|shangho';
#$commands     = 'redakt[oui]|aldon[oui]'; # .'|dokumento|artikolo|historio|propono'
$separator    = "=" x 80 . "\n";

################ la precipa masho de la programo ##############

###$| = 1;
#$the_mail   = '';
$editor     = '';
$article_id = '';
#$mail_date  = '';
$shangho    = '';
#$komando    = '';
#$file_no    = 0;
#@newarts    = ();


# certigu, ke provizoraj dosierujoj ekzistu
mkdir($tmp); 
mkdir($log_dir);
mkdir($xml_temp);
mkdir($rez_dir); 

$json_parser = JSON->new->allow_nonref;
#$json_parser->allow_tags(true);

# legu redaktantoj el JSON-dosiero kaj transformu al HASH por 
# trovi ilin facile laŭ numero (red_id)
$editors=read_json_file($editor_file);
$ed_hashs=();
# %editors = map { $_->{retadr}[0] => $_	} @{$fe};

$sigelilo = $ENV{"SIGELILO"} || read_file("$sigelilo_file");
$sigelilo =~ s/^\s+|\s+$//g;
unless ($sigelilo) {
	die "Mankas sigelilo. Sen ĝi ni ne povas kontroli la sigelojn de redaktoj."
}

write_file(">", $mail_send,"[\n"); my $mail_send_sep = '';

foreach my $file (glob "$gist_dir/*") {

    print $separator if ($verbose);

    # preparu por la nova mesagho
    $editor = '';
    $shangho = '';
    $article_id = '';

    # malfermu kaj enlegu la giston
	#$gist = read_json_file("$gist_dir/$file");
	$gist = read_json_file("$file");
    unless ($gist) {
		next;
    }

	# eligu iom da informo pri la gisto
	if ($verbose) {
		print 
			"id:",$gist->{"id"},"\n",
			"date:",$gist->{"updated_at"},"\n",
			"desc:",$gist->{"description"},"\n";
	}

    # analizu la enhavon de la mesagho
    process_gist($gist);
}

write_file(">>",$mail_send,"\n]\n");


print $separator if ($verbose);

# sendu raportojn
# provizore jam nun konektur al SMTP, por trovi eraron en ->auth
#$IO::Socket::SSL::DEBUG=3;
if (-s $mail_send > 10) {
	my $mailer = mailsender::smtp_connect;
	send_reports($mailer);
	mailsender::smtp_quit($mailer);
}

print $separator if ($verbose);

#send_newarts_report();
#git_push();
git_cmd("$git push origin master");

print $separator if ($verbose);

#
## arkivu la poshtdosieron
#if ($mail_file eq $mail_local) {
#    print "\nshovas $mail_local al $old_mail/$filename\n" if ($verbose);
#    `mv $mail_local $old_mail/$filename`;
#}
#
#if (-e $mail_error) {
#    print "shovas $mail_error al $err_mail/$filename\n" if ($verbose);
#    `mv $mail_error $err_mail/$filename`;
#}

if (-s $mail_send > 10) {
	$filename = "mail_sent_".`date +%Y%m%d_%H%M%S`;    
    print "ŝovas $mail_send al $log_dir/$filename\n" if ($verbose);
    `mv $mail_send $log_dir/$filename`;
}  

print $separator if ($verbose);

exit;


###################### analizado de la mesaghoj ################

sub process_gist {
    my $gist = shift;
	my $xmltxt = '';
	
	# legu aldonajn informojn pri la gisto
	my $info = read_json_file("$json_dir/".$gist->{id}.".json");
    unless ($info) {
		warn "Mankas aldonaj informoj, ne eblas trakti giston: ".$gist->{id};
		return;
	}
	print "info: ",Dumper($info) if ($verbose);

	# kontrolu, ĉu la gisto estas celata al la aktiva Git-arĥivo
	unless ($info->{celo}) {
		warn "Mankas celo en la aldonaj informoj, ni do ignoras tiun giston: ".$gist->{id};
		return;
	}
	my ($repo,@path) = split('/',$info->{celo});
	print ("gist-repo: $repo =? git_repo: $git_repo\n") if ($debug);
	unless ($git_repo eq $repo) {
		warn "Ni ne traktas gistojn por '$repo'. Do ni ignoras giston: ".$gist->{id}."\n";
		return;
	}

	unless ($gist->{description}) {
		warn "Mankas priskribo en: ".$gist->{id}."\n";
		return;
	}

	my @desc = split(':',$gist->{description});
    
    # kontrolu, ĉu temas pri registrita redaktoro 
	$editor = is_editor($desc[0]);
    unless ($editor) 
    { 
		warn "Ne registrita redaktanto: ".$desc[0];
		return;
	}    
	
    # print "redaktanto: ",Dumper($editor) if ($debug);
	#unless($info->{red_nomo} eq $editor->{red_nomo}) {
	#	warn "Nomo de la redaktanto ".$info->{red_id}." (".$info->{red_nomo}.") devias "
	#	 	."de la registrita nomo (".$editor->{red_nomo}.")!\n"
	#	# nur avertu, sed akceptu devion		
	#}

	# kontrolu sigelon
	unless(check_signature_valid($gist,$editor,$info)) {
		warn "La sigelo por gisto ".$gist->{id}." (".$info->{sigelo}.") ne pruviĝis valida.\n";
		return;
	}

	# traktu priskribon redakt/aldon..., XML...

	if ($desc[1] =~ /^\s*redakt[oui]\s*$/i) {
		return cmd_redakt($gist, $info, $desc[2]);

	} elsif ($desc[1] =~ /^\s*aldon[oui]\s*$/i) {
		return cmd_aldon($gist, $info, $desc[2]);

	} else {
		report($gist, {
			"rezulto"=>"eraro",
			"artikolo"=>'???',
			"mesagho"=> "priskribo ne obeas la konvencion ".$gist->{description}
		});
		return;
	}
}

sub is_editor {
    my $red7 = shift;

    # trovu laŭ jam kalkulitaj Sha
	my $ed = $ed_hashs{$red7};
	
	if ($ed) {
		return $ed;
	}

	# se ne troviĝis, trairu la liston kaj kalkulu dume la Sha-ojn
	for $ed (@$editors) {
		for my $ra (@{$ed->{retadr}}) {
			my $hash = substr(sha1_hex($ra),0,7);
			$ed_hashs{$hash} = $ed;

			return $ed if ($red7 eq $hash);
		}
	}

	# ne trovita
	return;
}



######################### respondoj al sendintoj ###################

sub report {
    my ($gist, $detaloj) = @_;
    
    print $detaloj->{mesagho}."\n" if ($verbose);

    $detaloj->{senddato} = $gist->{updated_at};
	write_json_file(">","$rez_dir/$gist->{id}", $detaloj);

	$detaloj->{sendinto} = $editor->{red_nomo}." <".$editor->{retadr}[0].">";
	write_json_file(">>",$mail_send, $detaloj, $mail_send_sep);
	$mail_send_sep = ',';
}

sub rep_str {
	my $rep = shift;
	
	my $msg = 
		"senddato: $rep->{senddato}\n"
		."artikolo: $rep->{artikolo}\n"
		.uc($rep->{rezulto}).": "	
		.$rep->{mesagho}."\n";	
	return $msg;
}

sub send_reports {
	my $mailer = shift;

    my %reports = ();
    my %dosieroj = ();
    my $mail_addr;

	print "sendas raportojn al redaktintoj...\n" if ($verbose);

	# kolektu raportojn laŭ retadreso
	my $reps = read_json_file($mail_send);
	for my $rep (@$reps) {
		
		if ($rep->{sendinto}) {
			$mail_addr = $rep->{sendinto};
			
			# chu dosierojn sendu?
			if ($rep->{dosiero}) {
				push(@{$dosieroj{$mail_addr}},[$rep->{dosiero},$rep->{artikolo}])
			}
			push(@{$reports{$mail_addr}},$rep);

		} else {
			warn "Ne povis elpreni sendinton el $_\n";
			next;
		}
	}

	# print "dosieroj: ",Dumper(%dosieroj) if ($debug);

	# forsendu la raportojn
	while (my ($maddr,$report) = each %reports) {

		$message = "Saluton!\nJen raporto pri via(j) sendita(j) artikolo(j).\n\n";
		for (@$report) {
			$message .= $separator. rep_str($_);
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
		print "dosieroj{maddr}: ",Dumper(@{$dosieroj{$maddr}}) if ($debug);
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
				
			print "attach: $file\n" if ($debug);
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
			warn "Ne povas forsendi retpoŝtan raporton!\n";
			next;
		}
	}

	#mailsender::smtp_quit($mailer);
}

###################### komandoj kaj helpfunkcioj ##############

# redakto de jam ekzistanta artikolo
sub cmd_redakt {
    my ($gist,$info,$shangho) = @_;
	my $fname = "$xml_dir/".$gist->{id}.".xml";
    #$shangho = $shangh; # memoru por poste
    #$shangho =~ s/[\200-\377]/?/g; # forigu ne-askiajn signojn
	print "redakto: $shangho\n" if ($debug);

    # pri kiu artikolo temas, trovighas en <art mrk="...">
	my $article_id = get_art_id($fname);
    my $art = extract_article($gist,$article_id);

    unless ($art =~ /^[a-z0-9_]+$/i) {
		report($gist,
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
    if (checkxml($gist,$fname,$article_id,0)) {
		return checkin($gist,$info,$art,$article_id,$shangho,$fname);
    }
	return;
}

# nova artikolo
sub cmd_aldon {
    my ($gist, $info, $art) = @_;
	my $fname = "$xml_dir/".$gist->{id}.".xml";

    # kio estu la nomo de la nova artikolo
    $art =~ s/^\s+//s;
    $art =~ s/\s+$//s;
    
    unless ($art =~ /^[a-z0-9_]+$/s) {
		report($gist, { 
			"rezulto"=>"eraro",
			"mesagho" => "Ne valida nomo por artikolo. \"$art\".\n"
	       	  			."Ĝi konsistu nur el minuskloj, substrekoj kaj ciferoj.",
			"dosiero" => $fname,
			"artikolo" => $art
		});
		return;
    }
    my $shangho = $art; # memoru por poste
    print "nova artikolo: $art\n" if ($verbose);

    # bezonighas article_id en kazo de eraro
    $article_id = "\044Id: $art.xml,v\044";

    # kontrolu, ĉu la dosiernomo estas ankoraŭ uzebla
	$xml_file = git_art_path($info, $art);
    if (-e "$xml_file") {
		report($gist, {
			"rezulto"=>"eraro",
			"mesagho" => "Artikolo kun la dosiernomo $art.xml jam ekzistas\n"
			   			."Bv. elekti alian nomon por la nova artikolo.",
			"dosiero" => $fname,
			"artikolo" => $article_id
		});
		return;
    }

    # kontroli la sintakson kaj arĥivi
    if (checkxml($gist,$fname,$article_id,1)) {
		return checkinnew($gist,$info,$art,$article_id,$shangho,$fname);
    }
	return;
}

sub check_signature_valid {
	my ($gist,$editor,$info) = @_;

	my $fname = "$xml_dir/".$gist->{id}.".xml";
	my $retadr = $editor->{retadr}[0];

	$text = "$retadr\n".read_file($fname);
	$digest = hmac_sha256_hex($text, $sigelilo);

	print "sigelo: $info->{sigelo}\n" if ($verbose);
	print "digest: $digest\n" if ($verbose);

	##if ($debug && ($digest ne $info->{sigelo})) {
	##	print "<<<$sigelilo>>>\n";
	##	print "[[[$text]]]\n";
	##}

	return ($digest eq $info->{sigelo})
}

sub checkxml {
    my ($gist,$fname,$article_id,$nova) = @_;
	my $lname = "$xml_temp/".$gist->{id}.".log";

    # aldonu dtd symlink se ankoraŭ mankas
    #symlink("$dtd_dir","$xml_temp/../dtd") ;
#	|| warn "Ne povis ligi de $dtd_dir al $xml_temp/../dtd\n";

	$teksto = read_file("$fname");
    # uniksajn linirompojn!
    $teksto =~ s/\r\n/\n/sg;

	# ĉe nova artikolo, enŝovu Id, se mankas...
	if ($nova) { $teksto =~ s/<art[^>]*>/<art mrk="\044Id\044">/s };

    # enmetu Log se ankorau mankas...
    unless ($teksto =~ /<!--\s+\044Log/s) {
		$teksto =~ s/(<\/vortaro>)/\n<!--\n\044Log\044\n-->\n$1/s;
    }

    # mallongigu Log al 20 linioj
    $teksto =~ s/(<!--\s+\044Log(?:[^\n]*\n){20})(?:[^\n]*\n)*(-->)/$1$2/s;

    # reskribu la dosieron
    unless (write_file(">",$fname,$teksto)) { return; }

    # kontrolu la sintakson de la XML-teksto
    `$xmlcheck $fname 2> $lname`;

    # legu la erarojn
    my $err = read_file($lname);
    # unlink("$lname");

    if ($err) {
		$err .= "\nkunteksto:\n".xml_context($err,"$fname");
		print "XML-eraroj:\n$err" if ($verbose);

		report($gist, {
			"rezulto" => "eraro",
			"mesagho" => "La XML-dosiero enhavas la sekvajn "
						."sintakserarojn:\n$err",
			"artikolo" => $article_id,
			"dosiero" => $fname
		});
		return;
    } else {
		print "XML: en ordo\n" if ($debug);
		return 1;
    }
}

sub checkin {
    my ($gist,$info,$art,$id,$shangho,$fname) = @_;
    my ($log,$err,$edtr);

    # kontrolu chu ekzistas shangh-priskribo
    unless ($shangho) {
	  	report($gist, {
		  	"rezulto" => "eraro",
		  	"mesagho" => "Vi forgesis indiki, kiujn ŝanĝojn vi faris "
	    				."en la dosiero.",
			"artikolo" => $id,
			"dosiero" => $fname
	  	});
      	return;
    } 
    print "ŝanĝoj: $shangho\n" if ($verbose);

    # skribu la shanghojn en dosieron
    $edtr = $editor->{red_nomo};
    #$edtr =~ s/\s*<(.*?)>\s*//;

	write_file(">","$tmp/shanghoj.msg","$edtr: $shangho");

    # kontrolu, chu la artikolo bazighas sur la aktuala versio
	my $repo_art_file = git_art_path($info,$art);

	unless (-e $repo_art_file) {
		report($gist, {
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

    my $ark_id = get_art_id($repo_art_file);

    # eble tro strikta: if ($ark_id ne $id) {
 	if (substr($ark_id,0,-19) ne substr($id,0,-19)) {
		# versiokonflikto
		report($gist, {
			"rezulto" => "eraro",
			"mesagho" => "La de vi sendita artikolo\n"
	       		 		."ne baziĝas sur la aktuala arkiva versio\n"
	       				."($ark_id)\n"
	       				."Bonvolu preni aktualan version el la TTT-ejo. "
	       				."($vokomail_url?art=$art)",
			"shangho" => $shangho,
			"dosiero" => $fname,
			"artikolo" => $id
		});
		return;
    }

#    # checkin in CSV
#    my $xmlfile="$art.xml";
#    `cp $xml_temp/xml.xml $xml_dir/$xmlfile`;
#
#   chdir($xml_dir);
#	checkin_csv($xmlfile);

	# checkin in Git
	print "cp ${fname} $repo_art_file\n" if ($verbose);
    `cp ${fname} $repo_art_file`;

	my $ok = checkin_git($gist,$repo_art_file,$edtr,$id);

	unlink("$tmp/shanghoj.msg");

	return $ok;
}


sub checkin_git {
	my ($gist,$xmlfile,$edtr,$shangho,$id) = @_;

	incr_ver("$xmlfile");

	my ($log1,$err1) = git_cmd("$git add $xmlfile");
	my ($log2,$err2) = git_cmd("$git commit -F $tmp/shanghoj.msg");

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
# ni ne bezonas dum ni arĥivas unue en CVS:		
#		report("ERARO   : La sendita artikolo shajne ne diferencas de "
#			."la aktuala versio.");
		return;
    } elsif ($err2 !~ /^\s*$/s) {
		report($gist, {
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
    report($gist, {
		"rezulto" => "konfirmo",
 		"artikolo" => $id,
		"shangho" => $shangho,
		"mesagho" => $log2
	});
	return 1;
}

sub checkinnew {
    my ($gist,$info,$art,$id,$shangho,$fname) = @_;

    $shangho = "nova artikolo";
    print "shanghoj: $shangho\n" if ($verbose);

    # skribu la shanghojn en dosieron
    my $edtr = $editor->{red_nomo};
    #$edtr =~ s/\s*<(.*?)>\s*//;

    write_file(">","$tmp/shanghoj.msg","$edtr: $shangho");

	my $repo_art_file = git_art_path($info,$art);

	# checkin in Git
    print "cp $fname $repo_art_file\n" if ($debug);
    `cp $fname $repo_art_file`;

	my $ok = checkinnew_git($gist,$repo_art_file,$edtr,$id);

	unlink("$tmp/shanghoj.msg");

	return $ok;
}


sub checkinnew_git {
	my ($gist,$xmlfile,$edtr,$id) = @_;

	init_ver("$xmlfile");

	($log1,$err1) = git_cmd("$git add $xmlfile");
	($log2,$err2) = git_cmd("$git commit -F $tmp/shanghoj.msg");

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
# ni ne bezonas dum ni arĥivas unue en CVS:		
#		report("ERARO   : La sendita artikolo shajne ne diferencas de "
#			."la aktuala versio.");
		return;
    } elsif ($err2 !~ /^\s*$/s) {
		report($gist, {
			"rezulto" => "eraro",
			"mesagho" => "Eraro dum arkivado de la nova artikolversio:\n"
						."$log1\n$log2\n$err1\n$err2\n",
			"artikolo" => $id,
			"dosiero" => $xmlfile
		});
		return;
    }

    # raportu sukceson 
    report($gist, {
		"rezulto" => "konfirmo",
		"artikolo" => $id,
		"mesagho" => $log2
	});
	return 1;
}

sub incr_ver {
	my $artfile = shift;

	# $Id: test.xml,v 1.51 2019/12/01 16:57:36 afido Exp $
    my $art = read_file("$artfile");

	$art =~ m/\$Id:\s+([^\.]+)\.xml,v\s+(\d)\.(\d+)\s+(?:\d\d\d\d\/\d\d\/\d\d\s+\d\d:\d\d:\d\d)(.*?)\$/s;	
	my $ver = id_incr($2,$3);
	my $id = '$Id: '.$1.'.xml,v '.$ver.$4.'$';
	$art =~ s/\$Id:[^\$]+\$/$id/;
	$art =~ s/\$Log:\s+([^\.]+)\.xml,v\s+\$(.*?)-->/log_incr($1,$2,$ver)/se;

	write_file(">",$artfile,$art);
}

sub id_incr {
	my ($major,$minor) = @_;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
	my $now = sprintf("%04d/%02d/%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
	return "$major.". ( ++$minor )." $now";
}

sub log_incr {
	my ($fn,$log,$ver) = @_;

	# mallongigu je maks. 10 linioj
	my @lines = split(/\n/,$log);
	$log = join("\n",splice(@lines,0,20));

	my $shg = read_file("$tmp/shanghoj.msg");

	return "\$Log: $fn.xml,v \$\nversio $ver\n".$shg."\n$log\n-->";
}


sub init_ver {
	my $artfile = shift;

	# $Id: test.xml,v 1.1 2019/12/01 16:57:36 afido Exp $
    my $art = read_file("$artfile");

	my $shg = read_file("$tmp/shanghoj.msg");

	$artfile =~ m|/([^/]+\.xml)|;
	my $fn = $1;
	my $ver = id_incr("1","0");
	my $id = '$Id: '.$fn.',v '.$ver.' afido Exp $';
	my $log = "\n<!--\n\$Log: $fn,v \$\nversio $ver\n$shg\n-->\n";

	$art =~ s/\$Id:[^\$]*\$/$id/;
	$art =~ s/<\/vortaro>/$log<\/vortaro>/s;

	write_file(">",$artfile,$art);
}

sub xml_context {
    my ($err,$file) = @_;
    my ($line, $char,$result,$n,$txt);

	if ($err =~ /line\s+([0-9]+)\s+char\s+([0-9]+)\s+/s) {
		$line = $1;
		$char = $2;

		unless (open XML,$file) {
			warn "Ne povis malfermi $file:$!\n";
			return '';
		}

		# la linio antau la eraro
		if ($line > 1) {
			for ($n=1; $n<$line-1; $n++) { <XML>; }	    
			$result .= "$n: ".<XML>;
			$result =~ s/\n?$/\n/s;
		}

		$result .= "$line: ".<XML>;
		$result =~ s/\n?$/\n/s;
		$result .= "-" x ($char + length($line) + 1) . "^\n";

		if (defined($txt=<XML>)) {
			$line++;
			$result .= "$line: $txt";
			$result =~ s/\n?$/\n/s;
		}

		close XML;			
		return $result;
    }

    return '';
}

sub git_art_path {
	my ($info,$art) = @_;
	my @parts = split('/',$info->{celo});
	my $path = join('/',splice(@parts,1));

	print "path: $path\n" if ($debug);
	return "$git_dir/$path/$art.xml";
}	

sub get_art_id {
    my $artfile = shift;

    # legu la ghisnunan artikolon
	my $xml = read_file($artfile);

	if ($xml) {
		# pri kiu artikolo temas, trovighas en <art mrk="...">
		$xml =~ /(<art[^>]*>)/s;
		$1 =~ /mrk="([^\"]*)"/s; 
		my $id = $1;
		print "Id: $id\n" if ($debug);  

		return $id;

	} else {
		return;
	}
}

sub extract_article {
    my ($gist,$id) = @_;
    # ekstraktu dosiernomon el $Id: ...
    unless ($id =~ /^\044Id: ([^ ,\.]+)\.xml,v\s+[0-9\.]+/) {
		report($gist, {
			"rezulto" => "eraro",
			"mesagho" => "Artikol-marko havas malĝustan sintakson",
			"artikolo" => $id
		});
		warn "$id ne enhavas dosiernomon\n";
		return '???';
    } else {
		return $1;
    }
}

sub read_file {
	my $file = shift;
	unless (open FILE, $file) {
		warn "Ne povis malfermi '$file': $!\n";
		return;
	}
	my $text = join('',<FILE>);
	close FILE;
	return $text;
}

sub write_file {
	my ($mode, $file, $text) = @_;

	unless (open FILE, $mode, $file) {
		warn "Ne povis malfermi '$file': $!\n";
		return;
	}
	print FILE $text;
	close FILE;
}

sub read_json_file {
	my $file = shift;
  	my $j = read_file($file);

	print "json file: $file\n" if ($debug);
    print substr($j,0,20),"...\n" if ($debug);

	# https://stackoverflow.com/questions/7809740/how-can-i-catch-a-failed-to-decode-json-error-message-in-perl

	unless ($j) {
		warn "Malplena aŭ mankanta JSON-dosiero '$file'";
		return;
	}

    my $parsed = $json_parser->decode($j);
	unless ($parsed) {
		warn "Ne eblis analizi enhavon de JSON-dosiero '$file'.\n";
		return;
	}
	return $parsed;	  
}

sub write_json_file {
	my ($mode,$file,$content,$sep) = @_;
    my $json = $json_parser->encode($content);

    unless (open JSN, $mode, $file) {
		warn "Ne povis malfermi $file: $!\n";
		return;
    }

	print JSN $sep if ($sep);
	print JSN $json;
	close JSN;  
}

sub git_cmd {
	my $git_cmd = shift;

	chdir($git_dir);
	print "------------------------------\n" if ($verbose);
	# `$git commit -F $tmp/shanghoj.msg --author "revo <$revo_mailaddr>" $xmlfile 1> $tmp/git.log 2> $tmp/git.err`;
	print "$git_cmd\n" if ($verbose);
	`$git_cmd 1> $tmp/git.log 2> $tmp/git.err`;

	# chu 'commit' sukcesis?
	my $log = read_file("$tmp/git.log");
    print "git-out:\n$log\n" if ($log || $debug);

    my $err = read_file("$tmp/git.err");
    print "git-err:\n$err\n" if ($err || $debug);
	print "------------------------------\n" if ($verbose);

    unlink("$tmp/git.log");
	unlink("$tmp/git.err");
	chdir($dict_base);

	return ($log,$err);
}