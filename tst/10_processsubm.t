# t/mein_test.t
use strict;
use warnings;
use Test::More; # tests => 2; 

use Encode qw(encode decode);

use lib('./bin');
use process qw(sys_run my_name timestamp trim);
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


my $utf8 = 'eĥoŝanĝo ĉiuĵaŭde EĤOŜANGO ĈIUĴAŬDE';
my $art_id = '$Id: artiko.xml,v 1.52 2025/10/08 16:37:51 revo Exp $';

# Encode to Latin3 bytes
is( extract_article({},$art_id), 'artiko', 'ekstrakti dosiernomon el artikolmarko');

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

`echo "testshangho" > $process::CFG->{tmp}/shanghoj.msg`;


checkinnew({
    desc=>'nov'
    },'nov','nov',$xmlfile);

done_testing();
