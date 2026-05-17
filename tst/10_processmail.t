# t/mein_test.t
use strict;
use warnings;

use utf8; use open ':std', ':encoding(UTF-8)';
use Test::More; # tests => 2; 

use Encode qw(encode decode);
use Data::Dumper;

use lib('./bin');
require 'processmail.pl';

# adapti agordon

$main::CFG->{dict_home}    = $ENV{PWD}; # $ENV{"HOME"},
$main::CFG->{afido_dir}    = "$ENV{PWD}/dict"; #"/var/afido", 
$main::CFG->{dict_base}    = "$main::CFG->{dict_home}/dict"; # xml, dok, dtd

#	dict_etc     => $ENV{"HOME"}."/etc", #"/run/secrets", # redaktantoj

$main::CFG->{tmp}         = "$main::CFG->{afido_dir}/tmp";
$main::CFG->{log_mail}    = "$main::CFG->{afido_dir}/log";
$main::CFG->{dtd_dir}     = "$main::CFG->{dict_base}/dtd";
$main::CFG->{mail_folder} = "/var/spool/mail/".process::my_name(); #/var/spool/mail/tomocero";
$main::CFG->{parts_dir}   = "$main::CFG->{afido_dir}/tmp/mailparts";
$main::CFG->{mail_error}  = "$main::CFG->{tmp}/mailerr";
$main::CFG->{mail_send}   = "$main::CFG->{tmp}/mailsend";
$main::CFG->{xml_temp}    = "$main::CFG->{tmp}/xml";
$main::CFG->{dtd_temp}    = "$main::CFG->{tmp}/dtd";

$main::CFG->{old_mail}    = "$main::CFG->{log_mail}/oldmail";
$main::CFG->{err_mail}    = "$main::CFG->{log_mail}/errmail";
$main::CFG->{prc_mail}    = "$main::CFG->{log_mail}/prcmail";

$main::CFG->{xml_dir}     = "$main::CFG->{dict_base}/xml";
$main::CFG->{git_dir}     = "/tmp/test-repo";
$main::CFG->{dok_dir}     = "$main::CFG->{dict_base}/dok";

$main::CFG->{mail_local}  = "$main::CFG->{tmp}/mail";
$main::CFG->{editor_file} = "$main::CFG->{dict_etc}/voko.redaktantoj";
$main::CFG->{attachments} = "$main::CFG->{tmp}/mailatt/attchm".$$."_";

diag("processmail.pl-agordo: ".Dumper($main::CFG));


$process::CFG->{dict_home}= $ENV{'PWD'};
$process::CFG->{dict_base}= "$process::CFG->{dict_home}/dict"; # xml, dok, dt,
$process::CFG->{tmp}      = "$process::CFG->{dict_base}/tmp";
$process::CFG->{xml_temp} = "$process::CFG->{tmp}/xml";
$process::CFG->{git_dir}  = '/tmp/test-repo'; # "$CFG->{dict_base}/revo-fonto";
diag("process.pm-agordo: ".Dumper($process::CFG));

`mkdir -p dict/xml && mkdir -p dict/tmp/xml && rm dict/tmp/* && rm -rf dict/tmp/xml/*`;
`ln -s \$(pwd)/../voko-grundo/dtd dict/tmp/`;
`bin/create_test_repo.sh /tmp`;

my $utf8 = 'eĥoŝanĝo ĉiuĵaŭde EĤOŜANGO ĈIUĴAŬDE';
my $art_id = '$Id: artiko.xml,v 1.52 2025/10/08 16:37:51 revo Exp $';

# Encode to Latin3 bytes
#is( lat3_utf8( encode('iso-8859-3',decode('utf-8',$utf8)) ),$utf8,'rekodigo lat3 utf8');
is( decode('utf8', lat3_utf8( encode('iso-8859-3',$utf8) )),$utf8,'rekodigo lat3 utf8');
is( extract_article($art_id), 'artiko', 'ekstrakti dosiernomon el artikolmarko');
is( extract_version($art_id), '1.52', 'ekstrakti version el artikolmarko');

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
my $xmlfile = "$main::CFG->{xml_temp}/xml.xml";
open my $XML, ">", $xmlfile or die "Ne povas skribi al $xmlfile: $!\n";
print $XML $NOVA;
close $XML;

#`echo "testshangho 1" > $process::CFG->{tmp}/shanghoj.msg`;
$main::CTX->{shangho} = "testshangho 1";
$main::CTX->{editor} = 'Vigla Testanto <vigla_testanto@example.com>';

ok( checkinnew('nov','nov'), "checkinnew()" );
my ($out,$err) = process::git_cmd(qw(/usr/bin/git log -1));
like ($out,qr/Vigla Testanto: nova artikolo/,"Kontrolo de git-protokolo");


### ni provos reendeponejigi la saman dosieron,
# kio kaŭzu versikonflikton

open my $XML, ">", $xmlfile or die "Ne povas skribi al $xmlfile: $!\n";
print $XML $NOVA;
close $XML;

# kopion de la arĥivita dosiero ni bezonas en xml_dir
`cp $main::CFG->{git_dir}/revo/nov.xml $main::CFG->{xml_dir}/`;

#`echo "testshangho 2" > $process::CFG->{tmp}/shanghoj.msg`;
$main::CTX->{shangho} = "testshangho 2";

ok( ! checkin('nov','$Id$'), "checkin() malsukcesa pro versiokonflikto" );

# Ni ne ŝanĝis la version, kio kaŭzas versikonflikton,
# Tiun informon ni trovu en doserio 'mailsend'
my $report = process::read_file($main::CFG->{mail_send});
diag($report);

like ($report,qr/ne baziĝas sur la aktuala arkiva versio/s,"Versikonflikto en 'mailsend'");

##`rm -rf $main::CFG->{git_dir}`;

done_testing();
