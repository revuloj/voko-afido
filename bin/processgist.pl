#!/usr/bin/perl

# prenas la redaktitajn artikolojn el loka
# dosierujo kreita per elŝutado de Github-gistoj
# kaj analizas, sintakse kontrolas
# kaj arkivas (per Git) ilin.
#
# voku:
#  processgist.pl

use JSON;
use Digest::SHA qw(hmac_sha256_hex);
use Data::Dumper;

######################### agorda parto ##################

# kiom da informoj
$verbose      = 1;
$debug        = 1;

# FARENDA: legu tiujn el /docker swarm config/
# baza agordo
$afido_dir    = "/var/afido"; # tmp, log
$dict_home    = "."; #$ENV{"HOME"};
$dict_base    = "$dict_home/dict"; # xml, dok, dtd
$dict_etc     = $ENV{"HOME"}."/etc"; #"/run/secrets"; # redaktantoj
$vokomail_url = "http://www.reta-vortaro.de/cgi-bin/vokomail.pl";
$revo_url     = "http://purl.oclc.org/NET/voko/revo";
$mail_folder  = "/var/spool/mail/tomocero";

# FARENDA: legu tiujn el sekreto(j)(?)
$revoservo    = '[Revo-Servo]';
$revo_mailaddr= 'revo@reta-vortaro.de';
$redaktilo_from= 'revo@steloj.de';
$revolist     = 'wolfram';
$revo_from    = "Reta Vortaro <$revo_mailaddr>";
$signature    = "--\nRevo-Servo $revo_mailaddr\n"
    ."retposhta servo por redaktantoj de Reta Vortaro.\n";

# programoj
$xmlcheck     = '/usr/bin/rxp -V -s';
$git          = '/usr/bin/git';

# -t ne subtenata de ssmtp
#$sendmail     = '/usr/lib/sendmail -t -i';
$sendmail     = '/usr/lib/sendmail -i';

# dosierujoj
$tmp          = "$dict_base/tmp";
$log          = "$dict_base/log";
$dtd_dir      = "$dict_base/dtd";

#$mail_error   = "$tmp/mailerr";
$mail_send    = "$tmp/mailsend";
$xml_temp     = "$tmp/xml";
#$dtd_temp     = "$tmp/dtd";

$prc_gist     = "$log/prcgist";

$gist_dir     = "$dict_base/gists";
$json_dir     = "$dict_base/json";
$xml_dir      = "$dict_base/xml";
$git_dir      = "$dict_base/revo-fonto/revo";
#$dok_dir      = "$dict_base/dok";

$editor_file  = "$dict_etc/redaktantoj.json"; #"$dict_etc/voko.redaktantoj";

# diversaj
#$possible_keys= 'komando|teksto|shangho';
$commands     = 'redakt[oui]|aldon[oui]'; # .'|dokumento|artikolo|historio|propono'
$separator    = "=" x 50 . "\n";

################ la precipa masho de la programo ##############

$| = 1;
#$the_mail   = '';
$editor     = '';
$article_id = '';
#$mail_date  = '';
$shangho    = '';
$komando    = '';
$file_no    = 0;
#@newarts    = ();

# certigu, ke provizoraj dosierujoj ekzistu
mkdir($tmp); 
mkdir($log);
mkdir($xml_temp);

$json_parser = JSON->new->allow_nonref;
#$json_parser->allow_tags(true);

# legu redaktantoj el JSON-dosiero kaj transformu al HASH por 
# trovi ilin facile laŭ numero (red_id)
$fe=read_json_file($editor_file);
%editors = map { $_->{red_id} => $_	} @{$fe};

#opendir my $GISTS, $gist_dir or die "Ne povis legi gistojn el $gist_dir: $!\n";

foreach my $file (glob "$gist_dir/*") {
#while (my $file = readdir($GISTS)) {
	#next unless (-f $file); # ignoru dosierujojn

    print '-' x 50, "\n" if ($verbose);

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

#closedir $GISTS;

# sendu raportojn
send_reports();
#send_newarts_report();
git_push();

#$filename = `date +%Y%m%d_%H%M%S`;    
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

#if (-e $mail_send) {
#    print "shovas $mail_send al $prc_mail/$filename\n" if ($verbose);
#    `mv $mail_send $prc_mail/$filename`;
#}  

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
    
    # kontrolu, chu temas pri redaktoro au helpkrio
    unless ($editor = is_editor($info->{red_id})) 
    { 
		warn "Ne registrita redaktanto: ".$info->{red_id}."(".$info->{red_nomo}.")";
		return;
	}    
	
    print "redaktanto: ",Dumper($editor) if ($debug);
	unless($info->{red_nomo} eq $editor->{red_nomo}) {
		warn "Nomo de la redaktanto ".$info->{red_id}." (".$info->{red_nomo}.") devias "
		 	."de la registrita nomo (".$editor->{red_nomo}.")!\n"
	}

	# traktu priskribon redakt/aldon..., XML...
	komando_lau_priskribo($gist)
}

sub is_editor {
    my $red_id = shift;

    # trovu laŭ red-id
	my $ed = %editors{$red_id};
	
    return $ed;
}

sub komando_lau_priskribo {
    my $gist = shift;
    my ($cmd,$arg);

	my $desc = $gist->{description};
    if ($desc =~ s/^[\s\n]*($commands)[ \t]*:[ \t]*(.*)//si) {
		$cmd = $1;
		$arg = $2;

		print "cmd: $cmd, arg: $arg\n" if ($debug);

		if ($cmd =~ /^redakt[oui]/i) {
			cmd_redakt($gist, $arg);

		} elsif ($cmd =~ /^aldon[oui]/i) {
			cmd_aldon($gist, $arg);

		} else {
			report("ERARO   : nekonata komando $cmd");
			return;
		}
	
    } else {
	 	warn "La priskribo ne konformas kun la konvencio: '$desc'\n";
		report("ERARO   : nekonata komando en la redakto");

		# kelkaj pseudaj variabloj necesaj
		$article_id = "???.xml";
		$komando = "???";
		$shangho = "???";

		# raportu eraron
		report("ERARO   : nekonata komando en la redakto","$desc");
		return;
    }
}



######################### respondoj al sendintoj ###################

sub report {
    my ($msg,$file) = @_;
    my ($attachment,$text);
    
    print "$msg\n" if ($verbose);

    # donu provizoran nomon al kunsendajho
    if ($file) {

		# enmetu "redakto: $shanghoj" komence
		if ($file =~ /\.xml$/) {
			unless (open FILE, $file) {
				warn "Ne povis malfermi $file: $!\n";
				goto "MOVE_FILE";
			}
			$text = join('',<FILE>);
			close FILE;
			unless (open FILE, ">$file") {
				warn "Ne povis malfermi $file: $!\n";
				goto "MOVE_FILE";
			}
			print FILE "$komando: $shangho\n\n";
			print FILE $text;
			close FILE;
		}
		
MOVE_FILE:
		# donu provizoran nomon al la dosiero
		$file_no++;
		$attachment = "$attachments$file_no";
		`mv $file $attachment`;
    }

    # skribu informon en $mail_send por poste sendi raporton al $editor
    unless (open SMAIL, ">>$mail_send") {
		warn "Ne povis malfermi $mail_send: $!\n";
		return;
    }

    print SMAIL "sendinto: $editor\n";
    print SMAIL "dosieroj: $attachment\n" if ($file);
    print SMAIL "senddato: $mail_date\n";
    print SMAIL "artikolo: $article_id\n";
    print SMAIL "shanghoj: $shangho\n" if ($shangho);
    print SMAIL "$msg\n";
    print SMAIL $separator;

    close SMAIL;
}

sub send_reports {
    my $newline = $/;
    my %reports = ();
    my %dosieroj = ();
    my ($mail_addr,$message,$mail_handle,$file,$art_id,$marko,$dos);

    # legu la respondojn el $mail_send
    if (-e $mail_send) {
	
	$/ = $separator;
	unless (open SMAIL, $mail_send) {
	    warn "Ne povis malfermi $mail_send: $!\n";
	    return;
	}

	while (<SMAIL>) {
	    # elprenu la sendinton
		if (s/^sendinto: *([^\n]+)\n//) {
			$mail_addr = $1;
			# chu dosierojn sendu?
			if (s/^dosieroj: *([^\n\s]+)\n//) {
				$dos = $1;
				if ($_ =~ /artikolo: *([^\n]+)\n/s) { $art_id = $1; }
				
				$dosieroj{$mail_addr} .= "$dos $art_id|";
			}
			$reports{$mail_addr} .= $_;
	    } else {
			warn "Ne povis elpreni sendinton el $_\n";
			next;
	    }
	}
	close SMAIL;
	$/ = $newline;

	# forsendu la raportojn
	while (($mail_addr,$message) = each %reports) {
	    $dos = $dosieroj{$mail_addr};
	    $mail_addr =~ s/.*<([a-z\.\_\-@]+)>.*/$1/;
	    
	    # preparu mesaghon
	    $message = "Saluton!\n"
		."Jen raporto pri via(j) sendita(j) artikolo(j).\n\n"
		    .$separator.$message."\n".$signature;
	    
	    $mail_handle = build MIME::Entity(Type=>"multipart/mixed",
					      From=>$revo_from,
					      To=>"$mail_addr",
					      Subject=>"$revoservo - raporto");
	    
	    $mail_handle->attach(Type=>"text/plain",
				 Encoding=>"quoted-printable",
				 Data=>$message);
	    
	    # alpendigu dosierojn
		if ($dos) {
			for $file (split (/\|/,$dos)) {
				if ($file =~ /^\s*([^\s]+)\s+(.+?)\s*$/) {
					$file = $1;
					$art_id = $2;

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
	    }
	    
	    # forsendu
	    unless (open SENDMAIL, "|$sendmail $mail_addr") {
		warn "Ne povas dukti al $sendmail: $!\n";
		next;
	    }
	    $mail_handle->print(\*SENDMAIL);
	    close SENDMAIL;
	}

	# forigu $mail_send
	# unlink($mail_send);
    }
}

#sub send_newarts_report {
#    my ($message,$mail_handle);
#
#    # legu la respondojn el $mail_send
#    if (@newarts) {
#
#	print "Informo pri novaj artikoloj al <$revolist>:\n",
#	    join ("\n",@newarts), "\n" if ($debug);
#	
#	# preparu mesaghon
#	$message = "Saluton!\nAldonighis " . ($#newarts+1)
#	    . " nova(j) artikolo(j)...\n\n";
#	foreach $entry (@newarts) {
#	    $message .= "$entry\n";
#	}
#	$message .= "\n$signature";
#	    
#	$mail_handle = build MIME::Entity(Type=>"text/plain",
#					  From=>$revo_from,
#					  To=>"$revolist",
#					  Subject=>"novaj artikoloj",
#					  Data=>$message);
#	    
#	# forsendu
#	unless (open SENDMAIL, "|$sendmail $revolist") {
#	    warn "Ne povas dukti al $sendmail: $!\n";
#	    return;
#	}
#	$mail_handle->print(\*SENDMAIL);
#	close SENDMAIL;
#    }
#}



###################### komandoj kaj helpfunkcioj ##############

# redakto de jam ekzistanta artikolo
sub cmd_redakt {
    my ($gist,$shangho) = @_;
    my $id,$art,$err,$teksto;
	my $fname = "$xml_dir/".$gist->{id}.".xml";
    #$shangho = $shangh; # memoru por poste
    #$shangho =~ s/[\200-\377]/?/g; # forigu ne-askiajn signojn
	print "redakto: $shangho\n" if ($debug);

	$teksto = read_file("$fname");
    # uniksajn linirompojn!
    $teksto =~ s/\r\n/\n/sg;

    # pri kiu artikolo temas, trovighas en <art mrk="...">
    $teksto =~ /(<art[^>]*>)/s;
    $1 =~ /mrk\s*=\s*"([^\"]*)"/s; 
    $id = $1;
    print "artikolo: $id\n" if ($verbose);
    $article_id = $id;

    # ekstraktu dosiernomon el $Id: ...
    #$id =~ /^\044Id: ([^ ,\.]+)\.xml,v\s+([0-9\.]+)/;
    $art = extract_article($id);

    unless ($art =~ /^[a-z0-9_]+$/i) {
		report("ERARO   : Ne valida artikolmarko $art. Ĝi povas enhavi nur "
	      ."literojn, ciferojn kaj substrekon.\n");
		return;
    }

    if (checkxml($gist,$fname,$teksto)) {
		checkin($gist,$art,$id,$shangho,$fname);
    }
}

# nova artikolo
sub cmd_aldon {
    my ($art,$teksto) = @_;
    my $id,$err,$teksto;

    # kio estu la nomo de la nova artikolo
    $art =~ s/^\s+//s;
    $art =~ s/\s+$//s;
    
    unless ($art =~ /^[a-z0-9_]+$/s) {
	report("ERARO   : Ne valida nomo por artikolo. \"$art\".\n"
	       ."Ghi konsistu nur el minuskloj, substrekoj kaj ciferoj.\n");
	return;
    }
    $shangho = $art; # memoru por poste

    # uniksajn linirompojn!
	$teksto = read_file("$xml_dir/".$gist->{id}.".xml");
    $teksto =~ s/\r\n/\n/sg;

    # la marko estu "\044Id\044"
    $teksto =~ s/<art[^>]*>/<art mrk="\044Id\044">/s;
    print "nova artikolo: $art\n" if ($verbose);

    # bezonighas article_id en kazo de eraro
    $article_id = "\044Id: $art.xml,v\044";

    # kontrolu, chu la dosiernomo estas ankorau uzebla
    if (-e "$xml_dir/$art.xml") {
	report ("ERARO   : Artikolo kun la dosiernomo $art.xml jam ekzistas\n"
	    ."Bv. elekti alian nomon por la nova artikolo.\n");
	return;
    }

    # kontroli la sintakson
    if (checkxml($teksto)) {
		checkinnew($art);
    }
}

sub checkxml {
    my ($gist,$fname,$teksto) = @_;
	my $lname = "$xml_temp/".$gist->{id}.".log";

    # aldonu dtd symlink se ankoraŭ mankas
    #symlink("$dtd_dir","$xml_temp/../dtd") ;
#	|| warn "Ne povis ligi de $dtd_dir al $xml_temp/../dtd\n";

    # enmetu Log se ankorau mankas...
    unless ($teksto =~ /<!--\s+\044Log/s) {
		$teksto =~ s/(<\/vortaro>)/\n<!--\n\044Log\044\n-->\n$1/s;
    }

    # mallongigu Log al 20 linioj
    $teksto =~ s/(<!--\s+\044Log(?:[^\n]*\n){20})(?:[^\n]*\n)*(-->)/$1$2/s;

    # reskribu la dosieron
    unless (open XML,">$fname") {
		warn "Ne povis skribi al $fname: $!\n";
		return;
    }

    print XML $teksto;
    close XML;

    # kontrolu la sintakson de la XML-teksto
    `$xmlcheck $fname 2> $lname`;

    # legu la erarojn
    my $err = read_file($lname);
    # unlink("$lname");

    if ($err) {
		$err .= "\nkunteksto:\n".xml_context($err,"$fname");
		print "XML-eraroj:\n$err" if ($verbose);

		report("ERARO   : La XML-dosiero enhavas la sekvajn "
			."sintakserarojn:\n$err","$fname");
		return;
    } else {
		print "XML: en ordo\n" if ($debug);
		return 1;
    }
}

sub checkin {
    my ($gist,$art,$id,$shangho,$fname) = @_;
    my ($log,$err,$edtr);

    # kontrolu chu ekzistas shangh-priskribo
    unless ($shangho) {
	  report("ERARO   : Vi fogesis indiki, kiujn ŝanĝojn vi faris "
	    ."en la dosiero.\n","$fname");
        return;
    } 
    print "shanghoj: $shangho\n" if ($verbose);

    # skribu la shanghojn en dosieron
    $edtr = $editor;
    $edtr =~ s/\s*<(.*?)>\s*//;

    open MSG,">$tmp/shanghoj.msg";
    print MSG "$edtr: $shangho";
    close MSG;

    # kontrolu, chu la artikolo bazighas sur la aktuala versio
    my $ark_id = get_archive_version($art);

    # eble tro strikta: if ($ark_id ne $id) {
 	if (substr($ark_id,0,-19) ne substr($id,0,-19)) {
		# versiokonflikto
		report("ERARO   : La de vi sendita artikolo\n"
	       ."ne baziĝas sur la aktuala arkiva versio\n"
	       ."($ark_id)\n"
	       ."Bonvolu preni aktualan version el la TTT-ejo. "
	       ."($vokomail_url?art=$art)\n","$fname");
		return;
    }

#    # checkin in CSV
#    my $xmlfile="$art.xml";
#    `cp $xml_temp/xml.xml $xml_dir/$xmlfile`;
#
#   chdir($xml_dir);
#	checkin_csv($xmlfile);

	# checkin in Git
	print "cp ${fname} ${git_dir}/${art}.xml" if ($verbose);
    `cp ${fname} ${git_dir}/${art}.xml`;

	chdir($git_dir);
###	checkin_git($xmlfile,$edtr);

	unlink("$tmp/shanghoj.msg");
}


sub checkin_git {
	my ($xmlfile,$edtr) = @_;

	incr_ver("$git_dir/$xmlfile");

	# `$git commit -F $tmp/shanghoj.msg --author "revo <$revo_mailaddr>" $xmlfile 1> $tmp/git.log 2> $tmp/git.err`;
	`$git commit -F $tmp/shanghoj.msg $xmlfile 1> $tmp/git.log 2> $tmp/git.err`;

	# chu 'commit' sukcesis?
    open LOG,"$tmp/git.log";
    $log = join('',<LOG>);
    print "git-log:\n$log\n" if ($debug);
    close LOG;

    open ERR,"$tmp/git.err";
    $err = join('',<ERR>);
    print "git-err:\n$err\n" if ($debug);
	close ERR;
  
    unlink("$tmp/git.log");
	unlink("$tmp/git.err");

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
    if ($log =~ /nothing\sto\scommit/s) {
# ni ne bezonas dum ni arĥivas unue en CVS:		
#		report("ERARO   : La sendita artikolo shajne ne diferencas de "
#			."la aktuala versio.");
		return;
    } elsif ($err !~ /^\s*$/s) {
		report("ERARO   : Eraro dum arkivado de la nova artikolversio:\n"
			."$log\n$err","$tmp/xml.xml");
		return;
    }

    # raportu sukceson 
# ni ne bezonas dum ni arĥivas unue en CVS:		
#    report("KONFIRMO: $log");
	return 1;
}

sub incr_ver {
	my $artfile = shift;

	# $Id: test.xml,v 1.51 2019/12/01 16:57:36 afido Exp $
    open ART,"$artfile";
    my $art = join('',<ART>);
    close ART;

	$art =~ m/\$Id:\s+([^\.]+)\.xml,v\s+(\d)\.(\d+)\s+(?:\d\d\d\d\/\d\d\/\d\d\s+\d\d:\d\d:\d\d)(.*?)\$/s;	
	my $ver = id_incr($2,$3);
	my $id = '$Id: '.$1.'.xml,v '.$ver.$4.'$';
	$art =~ s/\$Id:[^\$]+\$/$id/;
	$art =~ s/\$Log:\s+([^\.]+)\.xml,v\s+\$(.*?)-->/log_incr($1,$2,$ver)/se;

	open ART,">$artfile";
	print ART $art;
	close ART;
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

	open SHG, "$tmp/shanghoj.msg";
	my $shg = join('',<SHG>);
	close SHG;

	return "\$Log: $fn.xml,v \$\nversio $ver\n".$shg."\n$log\n-->";
}

sub git_push {
	chdir($git_dir);
	`$git push origin master 1> $tmp/git.log 2> $tmp/git.err`;

	# chu 'push' sukcesis?
    open LOG,"$tmp/git.log";
    $log = join('',<LOG>);
    print "git-log:\n$log\n" if ($debug);
    close LOG;

    open ERR,"$tmp/git.err";
	$err = join('',<ERR>);
	warn "git-err:\n$err\n" if ($err);
	close ERR;
  
    unlink("$tmp/git.log");
	unlink("$tmp/git.err");
}




sub checkinnew {
    my ($art) = @_;
    my ($log,$err,$edtr,$teksto);

    $shangho = "nova artikolo";
    print "shanghoj: $shangho\n" if ($verbose);

    # skribu la shanghojn en dosieron
    $edtr = $editor;
    $edtr =~ s/\s*<(.*?)>\s*//;

    open MSG,">$tmp/shanghoj.msg";
    print MSG "$edtr: $shangho";
    close MSG;

    # checkin CSV
    my $xmlfile="$art.xml";
	`cp $xml_temp/xml.xml $xml_dir/$xmlfile`;
	
	chdir($xml_dir);
	checkinnew_csv($xmlfile);

	# checkin in Git
    `mv $xml_temp/xml.xml $git_dir/$xmlfile`;

	chdir($git_dir);
	checkinnew_git($xmlfile,$edtr);

	unlink("$tmp/shanghoj.msg");
}

sub checkinnew_csv {
	my $xmlfile = shift;

	`$cvs add $xmlfile 1> $tmp/ci.log 2> $tmp/ci.err`;
    `$cvs ci -F $tmp/shanghoj.msg $xmlfile 1>> $tmp/ci.log 2>> $tmp/ci.err`;

    # chu checkin sukcesis?
    open LOG,"$tmp/ci.log";
    $log = join('',<LOG>);
    print "ci-log:\n$log\n" if ($debug);
    close LOG;

    # se finighas "done" - chio en ordo, 
    # se finighas "aborting" - fiasko
    # se neniu eligajho, la dosiero ne estas shanghita
    
    open ERR,"$tmp/ci.err";
    $err = join('',<ERR>);
    print "ci-err:\n$err\n" if ($debug);
    close ERR;

    # forigu provizorajn dosierojn
    unlink("$tmp/ci.log");
    unlink("$tmp/ci.err");

    # ignoru kelkajn mesaghojn, eligitaj de cvs add kiel "eraro"
    $err =~ s/\Acvs add: use.*?\Z//sg;
    $err =~ s/\Acvs add: scheduling.*?\Z//sg;
    $err =~ s/\Acvs add: re-adding.*?\Z//sig;

    # raportu erarojn
    if ($log =~ /^\s*$/s) {
	report("ERARO   : La sendita artikolo shajne ne arkivighis.",
	       "$tmp/xml.xml");
	return;
    } elsif (($log =~ /aborting\s*$/s) 
	     or ($err !~ /^\s*$/s)) {
	report("ERARO   : Eraro dum arkivado de la nova artikolversio:\n"
	      ."$log\n$err","$tmp/xml.xml");
	return;
    }

    # raportu sukceson
    push @newarts, ("$edtr: $art ( $revo_url/art/$art.html )");
    report("KONFIRMO: $log");
}

sub checkinnew_git {
	my ($xmlfile,$edtr) = @_;

	init_ver("$git_dir/$xmlfile");

	# `$git commit -F $tmp/shanghoj.msg --author "revo <$revo_mailaddr>" $xmlfile 1> $tmp/git.log 2> $tmp/git.err`;
	`$git add $xmlfile`;
	`$git commit -F $tmp/shanghoj.msg $xmlfile 1> $tmp/git.log 2> $tmp/git.err`;

	# chu 'commit' sukcesis?
    open LOG,"$tmp/git.log";
    $log = join('',<LOG>);
    print "git-log:\n$log\n" if ($debug);
    close LOG;

    open ERR,"$tmp/git.err";
    $err = join('',<ERR>);
    print "git-err:\n$err\n" if ($debug);
	close ERR;
  
    unlink("$tmp/git.log");
	unlink("$tmp/git.err");

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
    if ($log =~ /nothing\sto\scommit/s) {
# ni ne bezonas dum ni arĥivas unue en CVS:		
#		report("ERARO   : La sendita artikolo shajne ne diferencas de "
#			."la aktuala versio.");
		return;
    } elsif ($err !~ /^\s*$/s) {
		report("ERARO   : Eraro dum arkivado de la nova artikolversio:\n"
			."$log\n$err","$tmp/xml.xml");
		return;
    }

    # raportu sukceson 
# ni ne bezonas dum ni arĥivas unue en CVS:		
#    report("KONFIRMO: $log");
	return 1;
}

sub init_ver {
	my $artfile = shift;

	# $Id: test.xml,v 1.1 2019/12/01 16:57:36 afido Exp $
    open ART,"$artfile";
    my $art = join('',<ART>);
    close ART;

	open SHG, "$tmp/shanghoj.msg";
	my $shg = join('',<SHG>);
	close SHG;

	$artfile =~ m|/([^/]+\.xml)|;
	my $fn = $1;
	my $ver = id_incr("1","0");
	my $id = '$Id: '.$fn.',v '.$ver.' afido Exp $';
	my $log = "\n<!--\n\$Log: $fn,v \$\nversio $ver\n$shg\n-->\n";

	$art =~ s/\$Id:[^\$]*\$/$id/;
	$art =~ s/<\/vortaro>/$log<\/vortaro>/s;

	open ART,">$artfile";
	print ART $art;
	close ART;
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
	    for ($n=1; $n<$line-1; $n++) {
		<XML>;
	    }
	    
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

sub get_archive_version {
    my ($art) = @_;
    my $xmlfile = "$xml_dir/$art.xml";

    # legu la ghisnunan artikolon
    unless (open XMLFILE, $xmlfile) {
	warn "Ne povis legi $xmlfile: $!\n";
	return;
    }

    my $txt = join('',<XMLFILE>);
    close XMLFILE;

    # pri kiu artikolo temas, trovighas en <art mrk="...">
    $txt =~ /(<art[^>]*>)/s;
    $1 =~ /mrk="([^\"]*)"/s; 
    my $id = $1;
    print "malnova artikolo: $id\n" if ($debug);  

    return $id;
}

sub extract_version {
    my $id = shift;
    # ekstraktu version el $Id: ...
    unless ($id =~ /^\044Id: [^ ,\.]+\.xml,v\s+([0-9\.]+)/) {
		report ("ERARO   : Artikol-marko havas malghustan sintakson\n");
		warn "$id ne enhavas version\n";
		return '???';
    } else {
		return $1;
    }
}

sub extract_article {
    my $id = shift;
    # ekstraktu dosiernomon el $Id: ...
    unless ($id =~ /^\044Id: ([^ ,\.]+)\.xml,v\s+[0-9\.]+/) {
		report ("ERARO   : Artikol-marko havas malghustan sintakson\n");
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
	}
	my $text = join('',<FILE>);
	close FILE;
	return $text;
}

sub read_json_file {
	my $file = shift;
  	my $j = read_file($file);
    print substr($j,0,20),"...\n" if ($debug);

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
