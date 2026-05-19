#!/usr/bin/perl

use strict; use warnings;
use utf8; use open ':std', ':encoding(UTF-8)';
# pakaĵo de Debian/Ubunto: libtest-www-mechanize-perl
use Test::WWW::Mechanize;
use Test::More; use Test::Deep;
use URL::Encode qw(url_encode);

use lib('./bin');
use process;

my $SUBM_HOST = '127.0.0.1:8088';
my $SUBM_URL = "http://$SUBM_HOST/cgi-bin/vokosubmx.pl";

$ENV{'REVO_HOST'} = $SUBM_HOST;
$ENV{ADM_USER} = 'araneo';
require 'processsubm.pl';

# 0. adaptu agordojn

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


# transdonu registrita test-redaktanton en medivariablo,
# alie la testo fiaskos pro rifuzo de la redakto
my $redaktanto = $ENV{TEST_RETADRESO} || '_registrita_testredaktanto_@retavortaro.de';

unless ( $ENV{ADM_PASSWORD} ) {
    die "Vi devas transdoni ADM_PASSWORD tra medivariablo."
}

# 2. preparo de TTT-testkliento
my $mech = Test::WWW::Mechanize->new();

# kapoj
$mech->add_header('Accept' => '*/*');

my $xmlTxt = << '~~~~~';
<?xml version="1.0"?><!DOCTYPE vortaro SYSTEM "../dtd/vokoxml.dtd"><vortaro>
<art mrk="\$Id: kvin.xml,v 1.116 2021/06/22 19:02:35 revo Exp \$">
<kap><ofc>*</ofc><rad>kvin</rad></kap>
<drv mrk="kvin.0"><kap><tld/></kap>
<snc><dif>Kvar kaj unu. Matematika simbolo 5:<ekz><tld/> kaj sep faras dek du
<fnt><bib>F</bib><lok>&FE; 12</lok></fnt>;</ekz>
</dif><ref tip="lst" cel="nombr.0o.MAT" lst="voko:nombroj" val="5">nombro</ref>
</snc></drv></art></vortaro>
~~~~~


note($xmlTxt);

forsendo($xmlTxt,'Forsendi artikolon \'kvin\'');
# $mech->scraped_id_like('malkonfirmo', qr/problemo kun la retpoŝta servo/,'Send-eraro');
$mech->scraped_id_like('konfirmo', qr/Bone/,'Konfirmo de submeto');

# Nun ni provas trakti la submeton regule per processsubm.pl

main::MAIN();


done_testing();


sub forsendo {
    my ($xml,$testo) = @_;

    $mech->post_ok($SUBM_URL, 
        [
            art   => 'test',
            redaktanto  => $redaktanto,
            sxangxo  => 'nur testo', 
            nova => 0,
            command => 'forsendo',
            xmlTxt => $xml
        ],
        $testo
    );

    note($mech->ct);
    note($mech->content);

    #$mech->content_is('text/html; charset=utf-8');
    like(
        $mech->response->header('Content-Type'),
        qr{text/html;\s*charset=utf-?8}i,
        'Ĝusta enhavtipo (html, utf-8)'
    );

    $mech->title_is('vokosubmx', 'Titolo \'vokosubmx\' troviĝis');
    $mech->content_like(qr/<body>/, 'body...');
    $mech->content_like(qr/ni ne povas sendi al vi kopion/,'ne eblis sendi kopion');
    $mech->id_exists_ok('xml_err','Troviĝas alineo \'xml_err\'');
    $mech->id_exists_ok('ref_err','Troviĝas alineo \'ref_err\'');
}



