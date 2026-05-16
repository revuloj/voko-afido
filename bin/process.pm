#!/usr/bin/perl

# (c) 1999 - 2021 ĉe Wolfram Diestel
# laŭ GPL 2.0

use strict; use warnings;
use utf8; use open ':std', ':encoding(UTF-8)';

package process;
use Exporter 'import';
our @EXPORT_OK = qw($CFG);

# debian/ubuntu: libipc-run-perl
use IPC::Run qw(run); 

use JSON;
#$json_parser->allow_tags(true);

use Text::CSV;
use Encode;


#use File::Tempdir;
#my $tmpdir = File::Tempdir->new();
#my $tmp = $tmpdir->name;

our $CFG = {
	loglevel   => 'info',
	dict_home  => $ENV{"HOME"}, # por testi: $ENV{'PWD'},
	# git     => '/usr/bin/git',
	xmlcheck   => '/usr/bin/rxp -Vs',
};

$CFG->{dict_base}= "$CFG->{dict_home}/dict"; # xml, dok, dt,
$CFG->{tmp}      = "$CFG->{dict_base}/tmp";
$CFG->{xml_temp} = "$CFG->{tmp}/xml";
$CFG->{git_dir}  = "$CFG->{dict_base}/revo-fonto";

my $json_parser = JSON->new->allow_nonref;

# preparu protokolon
use Log::Dispatch;
my $log = Log::Dispatch->new(
    outputs => [
        #[ 'File',   min_level => 'debug', filename => 'logfile' ],
        [ 'Screen', min_level => $CFG->{loglevel} ],
    ],
);


# forigu spacojn komence kaj fine de signoĉeno
sub trim { my $s = shift; $s =~ s/^\s+|\s+$//gx; return $s };

################ helpfukcioj por ruli, legi kaj skribi dosierojn ##############

# rulas sistemkomandon kaj redonas STDOUT
sub sys_run {
  my @command = @_;

  my ($out, $err);
  run \@command, \undef, \$out, \$err or do {
    warn(join(' ',@command). ": $!\n$err\n");
  };
  return $out;
}

# rulas sistemkomandon kaj  redonas STDERR, ekz-e por XML-sintakskontrolo
sub sys_run_err {
  my @command = @_;

  my ($out, $err);
  # $log->info("cmd:".join(' ',@command));
  run \@command, \undef, \$out, \$err;
  # $log->info("cmd-out:".$out);
  # $log->info("cmd-err:".$err);
  return $err;
}

sub my_name {
	chomp (my $mi = sys_run('id','-un'));
	return $mi;
}

sub timestamp {
	chomp(my $ts = sys_run('date','+%Y%m%d_%H%M%S'));
	return $ts;
}

# legi dosieron
sub read_file {
	my $file = shift;
	# NOTO: ĝenerala trakto kiel utf8 kaŭzas problemon en forsendo de raportoj...
	# open body: Invalid argument at /usr/share/perl5/MIME/Entity.pm line 1892
	# do faru tion prefere post voko de read_file, kie necesas
	# my $text = decode('utf8', join('',<$FILE>));
	open my $FILE, "<", $file or do {
		$log->warn("Ne povis malfermi '$file': $!\n"); return;
	};
	my $text = do { local $/ = undef, <$FILE>};
	close $FILE;
	return $text;
}


# skribi dosieron
sub write_file {
	my ($mode, $file, $text) = @_;

    $log->debug("Skribas ".length($text)." bitokojn al: ".$file."\n");
	open my $FILE, $mode, $file or do {
		$log->warn("Ne povis malfermi '$file': $!\n"); return;
	};
	print $FILE $text;
	close $FILE;

	return 1;
}

# legi JSON-dosieron
sub read_json_file {
	my $file = shift;
  	my $j = read_file($file);

	$log->debug("json file: $file\n");

	unless ($j) {
		$log->warn("Malplena aŭ mankanta JSON-dosiero '$file'\n");
		return;
	}
    $log->debug(substr($j,0,20)."...\n");

    my $parsed;
	eval {
    	#$parsed = $json_parser->decode(decode('utf8', $j));
		$parsed = $json_parser->decode($j); # ni aldonis utf8 por ĉiu "open" supre!
    	1;
	} or do {
  		my $error = $@;
		$log->error("Ne eblis analizi enhavon de JSON-dosiero '$file'.\n");
  		$log->error("$error\n");
		return;
	};

	return $parsed;
}


# skribi JSON-dosieron
sub write_json_file {
	my ($mode,$file,$content,$sep) = @_;
    my $json = $json_parser->encode($content);

    open my $JSN, $mode, $file or do {
		$log->warn("Ne povis malfermi $file: $!\n"); return;
    };
	print $JSN $sep if ($sep);
	print $JSN $json;
	close $JSN; 

	return 1; 
}

# legu linion post linio el CSV-teksto kaj redonu kiel listo de vortaretoj 
sub csv2arr {
    my $csv = shift;
    my $parser = Text::CSV->new({ sep_char => ';' }); 

    my @lines = split("\n",$csv);
    my $first_line = 1;
    my %rec;
    my @cols;
    my @records;

    for my $line (@lines) {
       	$log->debug("CSV line: ".encode('utf-8',$line)."\n");
        chomp($line);
        if ($parser->parse($line)) {
            if ($first_line) {
                # unua linio enhavas la kolumno-nomojn
                @cols = $parser->fields();
               	$log->debug("CSV cols:".join(';',@cols)."\n");
                $first_line = 0;
            } else {
                # aliaj linioj estas la datumoj
                my @fields = $parser->fields();
                my %rec; 
                @rec{@cols} = @fields;
                #for (my $i=0; $i<=$#fields; $i++) {
                #    $rec{$cols[$i]} = $fields[$i];
                #}
               	#$log->debug("CSV cols:".join(';',@cols)."\n");
               	#$log->debug("CSV rec:".join(';',$parser->fields())."\n");
               	$log->debug("CSV keys:".join(',',keys %rec)."\n");
               	$log->debug("CSV vals:".encode('utf-8',join(',',values %rec))."\n");
                push @records,\%rec;
            }
        } else {
            $log->error("Eraro dum analizado de CSV: [$line]\n".$parser->error_diag ()."\n");
        }
    }

    $log->debug("CSV #recs:".(1+$#records)."\n");
    return @records;
}


################ helpfukcioj por raporti rezultojn ##############

# $rep referencu al vortareto kun la ŝlosiloj:
# "mesagho" mesaĝo pri eraro aŭ konfirmo
# "rezulto" "eraro" aŭ "konfirmo"
# "senddato" kiam la redakto estis alsendita
# "artikolo" la identigilo de la artikolo (<art mrk="$Id...")

sub rep_str {
	my $rep = shift;
	
	my $msg = 
		"senddato: $rep->{senddato}\n"
		."artikolo: $rep->{artikolo}\n"
		.uc($rep->{rezulto}).": "
		.$rep->{mesagho}."\n";
	return $msg;
}


################ helpfukcioj por trakti la XML-artikolon kaj ties identigilon/version ##############

# kontrolado de la XML-artikolo: marko ($Id$), sintakso
sub checkxml {
    my ($id,$fname,$nova) = @_;

    # se ne jam estas kreu provizoran xml-dosierujon
    mkdir($CFG->{xml_temp});

    # aldonu dtd symlink se ankoraŭ mankas
    #symlink("$dtd_dir","$xml_temp/../dtd") ;
#	|| warn "Ne povis ligi de $dtd_dir al $xml_temp/../dtd\n";

	my $teksto = read_file("$fname");
    # uniksajn linirompojn!
    $teksto =~ s/\r\n/\n/sgx;

	# ĉe nova artikolo, enŝovu Id, se mankas...
	if ($nova) { 
		$teksto =~ s{<art[^>]*>}{<art mrk="\044Id\044">}sx
	};

    # enmetu Log se ankorau mankas...
    unless ($teksto =~ /<!--\s+\044Log/sx) {
		$teksto =~ s{
			(<\/vortaro>)
		}{\n<!--\n\044Log\044\n-->\n$1}sx;
    }

    # mallongigu Log al 20 linioj
    $teksto =~ s{
		(<!--\s+
		\044Log
		(?:[^\n]*\n){20})
		(?:[^\n]*\n)*
		(-->)
	}{$1$2}sx;

    # reskribu la dosieron
    unless (write_file(">",$fname,$teksto)) { return; }

    # kontrolu la sintakson de la XML-teksto
    my $errors = sys_run_err(split(/ /,$CFG->{xmlcheck}),$fname);
	return $errors;
}

# en la artikolo troviĝas $Id....$, kiu enhavas i.a. version kaj tempon
sub get_art_id {
    my $artfile = shift;

    # legu la ghisnunan artikolon
	my $xml = read_file($artfile);

	if ( $xml && (my ($id) = $xml =~ m{
		<art[^>]*
		\bmrk\s*=\s*
		"([^"]*)"
	}sx) ) {
    	$log->debug("Id: $id\n");  
    	return $id;
	}
	
	return;
}

# La version ni eltrovos kaj altigos je unu kaj reskribas en la artikolon
# krome la artikolo piede enhavas komenton kun $Log$ por protokoli la lastajn ŝanĝoj
# ni aldonos supre la novan version kaj evt-e mallongigas la komenton
sub incr_ver {
	my ($artfile,$shangh_file) = @_;

	# $Id: test.xml,v 1.51 2019/12/01 16:57:36 afido Exp $
    my $art = read_file("$artfile");

	if ( $art =~ m{
		\$Id:\s+
		([^\.]+)\.xml,v\s+        # dosiero
		(\d)\.(\d+)\s+            # versio
		(?:\d{4}\/\d{2}\/\d{2}\s+ # dato
		\d\d:\d\d:\d\d)           # tempo
		(.*?)\$
	}sx ) {

		my $ver = id_incr($2,$3);
		my $id = '$Id: '.$1.'.xml,v '.$ver.$4.'$';
		$art =~ s{
			\$Id:
			[^\$]+\$
		}{$id}x;

		$art =~ s{
			\$Log
			[^\$]*\$
			(.*?)
			-->
		}{log_incr($1,$ver,$shangh_file)}sex;

		write_file(">",$artfile,$art);

		return 1;
	}
	return;
}

# altigi la version je .1 kaj alpendigi la aktualan daton 
sub id_incr {
	my ($major,$minor) = @_;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
	my $now = sprintf("%04d/%02d/%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
	return "$major.". ( ++$minor )." $now";
}

# ni legas la ŝanĝojn el dosiero shangoj.msg
# kaj metas kape de ŝanĝprotkoleto, kiu troviĝas piede de artikolo
# ni mallongigas ĝin al maksimume 20 linioj
sub log_incr {
	my ($alog,$ver,$shangh_file) = @_;

	# mallongigu je maks. 10 linioj
	my @lines = split(/\n/x,$alog);
	$alog = join("\n",splice(@lines,0,20));

	my $shg = decode('utf8', read_file($shangh_file));
	return "\$Log\$\nversio $ver\n".$shg."\n$alog\n-->";
}

# ĉe nova artikolo ni donas version 1.0 en $Id kun la dato
# kaj enŝovas $Log$ piede kun nur tiu ĉi unua versio kiel komento
sub init_ver {
	my ($artfile,$shangh_file) = @_;

	# $Id: test.xml,v 1.1 2019/12/01 16:57:36 afido Exp $
    my $art = read_file("$artfile");
	my $shg = decode('utf8', read_file($shangh_file));

	if ( $artfile =~ m{
		/([^/]+\.xml) # dosiernomo sen pado
	}x ) {

		my $fn = $1;
		my $ver = id_incr("1","0");
		my $id = '$Id: '.$fn.',v '.$ver.' afido Exp $';
		my $alog = "\n<!--\n\$Log: $fn,v \$\nversio $ver\n$shg\n-->\n";

		$art =~ s{\$Id[^\$]*\$}{$id}x;
		$art =~ s{<!--\s*\$Log[^>]+-->\s*<\/vortaro>}{$alog<\/vortaro>}sx;

		write_file(">",$artfile,$art);

		return 1;
	}

	return;
}

# Se la sintakskontrolo trovis erarojn, ni ricevas ĝin kun linio kaj pozicio ĉe
# la komenco de la eraromesaĝo. Per tiuj indikoj ni trovos la lokon en XML, kiu havas
# la eraron por doni helpinformon al la redaktinto.
sub xml_context {
    my ($err,$file) = @_;
    my ($line, $char,$result,$n,$txt);

	if ( $err =~ m{
			line\s+
			([0-9]+)\s+
			char\s+
			([0-9]+)\s+
	}sx ) {
		$line = $1;
		$char = $2;

		open my $XML, "<", $file or do {
			$log->warn("Ne povis malfermi $file:$!\n");
			return '';
		};

		# la linio antau la eraro
		if ($line > 1) {
			for ($n=1; $n<$line-1; $n++) { <$XML>; }
			$result .= "$n: ".<$XML>;
			$result =~ s/\n?$/\n/sx;
		}

		$result .= "$line: ".<$XML>;
		$result =~ s/\n?$/\n/sx;
		$result .= "-" x ($char + length($line) + 1) . "^\n";

		if (defined($txt=<$XML>)) {
			$line++;
			$result .= "$line: $txt";
			$result =~ s/\n?$/\n/sx;
		}

		close $XML;
		return $result;
    }

    return '';
}

################ helpfukcioj por Git ##############


sub git_cmd {
	my @git_cmd = @_;

	chdir($CFG->{git_dir});
	$log->info("------------------------------\n");
	$log->info(join(' ',@git_cmd)."\n");

  	my ($out, $err);
  	run \@git_cmd, \undef, \$out, \$err;

	# chu 'commit' sukcesis?
    $log->info("git-out:\n$out\n") if ($out);
    $log->error("git-err:\n$err\n") if ($err);
	$log->info("------------------------------\n");

	chdir($CFG->{dict_base});

	## no critic (RegularExpressions::RequireExtendedFormatting)
	$out =~ s/\[master\s+/[m /;
	$out =~ s/file changed/dosiero/;
	$out =~ s/insertions/enmetoj/;
	$out =~ s/deletions+/forigoj/;
	## use critic

	return ($out,$err);
}

return 1;
