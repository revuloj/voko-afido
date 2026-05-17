# t/mein_test.t
use strict;
use warnings;
use Test::More; # tests => 2; 
use utf8; use open ':std', ':encoding(UTF-8)';
#use Encode qw(encode decode);
use Data::Dumper;

use lib('./bin');
use process;
require 'processsubm.pl';

# adaptu agordojn

$main::CFG->{dict_home}   = $ENV{'PWD'};
$main::CFG->{dict_base} =  "$main::CFG->{dict_home}/dict"; # xml, dok, dtd
$main::CFG->{tmp}       =  "$main::CFG->{dict_base}/tmp";
$main::CFG->{log_dir}   =  "$main::CFG->{dict_base}/log";
$main::CFG->{mail_send} =  "$main::CFG->{tmp}/mailsend";
$main::CFG->{rez_dir}   =  "$main::CFG->{dict_base}/rez";
$main::CFG->{xml_dir}   =  "$main::CFG->{dict_base}/xml";
$main::CFG->{git_dir}   =  "/tmp/test-repo";
diag("processsubm.pl-agordo: ".Dumper($main::CFG));

$process::CFG->{dict_home}= $ENV{'PWD'};
$process::CFG->{dict_base}= "$process::CFG->{dict_home}/dict"; # xml, dok, dt,
$process::CFG->{tmp}      = "$process::CFG->{dict_base}/tmp";
$process::CFG->{xml_temp} = "$process::CFG->{tmp}/xml";
$process::CFG->{git_dir}  = '/tmp/test-repo'; # "$CFG->{dict_base}/revo-fonto";
diag("process.pm-agordo: ".Dumper($process::CFG));

`mkdir -p dict/tmp/xml && rm dict/tmp/* && rm -rf dict/tmp/xml/* && ln -s \$(pwd)/../voko-grundo/dtd dict/tmp/`;
`bin/create_test_repo.sh /tmp`;

my $utf8 = 'eĥoŝanĝo ĉiuĵaŭde EĤOŜANGO ĈIUĴAŬDE';
my $art_id = '$Id: artiko.xml,v 1.52 2025/10/08 16:37:51 revo Exp $';

$main::CTX->{editor}->{red_nomo} = 'Vigla Testanto';
$main::CTX->{editor}->{retadr} = ['vigla_testanto@example.com'];

# ĉar ni ne vokas MAIN, ni mem devas skribi komencon al mail_send
`echo "[" > $main::CFG->{mail_send}`;

# Encode to Latin3 bytes
is( extract_article({},$art_id), 'artiko', 'ekstrakti dosiernomon el artikolmarko');

### kreu novan artikolon kaj testu la endeponejigon

my $NOVA = <<'EON';
<?xml version="1.0"?>
<!DOCTYPE vortaro SYSTEM "../dtd/vokoxml.dtd">
<vortaro>
<art mrk="$Id$">
<kap>
  <ofc>*</ofc>
  <rad>nov</rad>/a <fnt><bib>UV</bib></fnt>
</kap>
<drv mrk="nov.0a">
  <kap><ofc>*</ofc><tld/>a</kap>
  <snc mrk="nov.0a.eka">
    <dif>
      Anta&ubreve;e ne ekzistanta a&ubreve; ne konata, unuafoje
      aperanta:
      <ekz>
        kiam vi ekparolis, ni atendis a&ubreve;di ion <tld/>an
        <fnt><bib>F</bib> <lok>&FE; 40</lok></fnt>;
      </ekz><ekz>
        <tld/>a libro, modo;
      </ekz>
    </dif>
  </snc>
</drv>
</art>
</vortaro>
EON

# ni povus uzi/testi process::write_file anst.
my $xmlfile = "$process::CFG->{xml_temp}/xml.xml";
open my $XML, ">", $xmlfile or die "Ne povas skribi al $xmlfile: $!\n";
print $XML $NOVA;
close $XML;

`echo "testshangho 1" > $process::CFG->{tmp}/shanghoj.msg`;

ok( checkinnew({
    desc => 'nov'
    },'nov','nov',$xmlfile), "checkinnew()" );
my ($out,$err) = process::git_cmd(qw(/usr/bin/git log -1));
like ($out,qr/Vigla Testanto: nova artikolo/,"Kontrolo de git-protokolo");

### endeponejigu ŝanĝon

`echo "testshangho 2" > $process::CFG->{tmp}/shanghoj.msg`;

ok( ! checkin({
    desc => 'ŝanĝo'
    },'nov','nov',$xmlfile), "checkin() malsukcesa pro versiokonflikto" );

# Ni ne ŝanĝis la version en la origina dosiero, kio kaŭzas versikonflikton,
# Tiun informon ni trovu en doserio 'mailsend'
`echo "]" >> $main::CFG->{mail_send}`;
my $json = process::read_json_file($main::CFG->{mail_send});
my $report = $json->[-1];

diag(Dumper($report));

like ($report->{mesagho},qr/ne baziĝas sur la aktuala arkiva versio/,"Versikonflikto en 'mailsend'");

# rekomencu mail_send
##`echo "[" > $main::CFG->{mail_send}`;
# my ($out,$err) = process::git_cmd(qw(/usr/bin/git log -1));
# like ($out,qr/Vigla Testanto: nova artikolo/,"Kontrolo de git-protokolo");

##`rm -rf $main::CFG->{git_dir}`;

done_testing();
