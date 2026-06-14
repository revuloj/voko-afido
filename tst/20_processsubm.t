#!/usr/bin/perl

# (c) 2026 ĉe Wolfram Diestel
# tio testas bin/processsubm.pl
# vi bezonas aktivan testmedion revo-medio/araneujo-t
# kaj agordon por uzi ties testan poŝtservon en /etc/mailsender.conf
# ${HOME}/etc/redaktantoj.json devas enhavi la retadreson de la
# testanto (mediovariablo $TEST_RETADRESO)

use strict; use warnings;
use utf8; use open ':std', ':encoding(UTF-8)';
# pakaĵo de Debian/Ubunto: libtest-www-mechanize-perl
use Test::WWW::Mechanize;
# libtest-more-perl
use Test::More; use Test::Deep; 
# libtest-output-perl
#use Test::Output;
# liblog-dispatch-array-perl
use Log::Dispatch::Array;
use URL::Encode qw(url_encode);
use Data::Dumper;

use lib('./bin');
use process;

my $SUBM_HOST = '127.0.0.1:8088';
my $SUBM_URL = "http://$SUBM_HOST/cgi-bin/vokosubmx.pl";
my $id_erar = '$Id: erar.xml,v 1.47 2025/03/14 06:18:12 revo Exp $';

# antaŭ require... ni devas difini kelkajn mediovariablojn por processsubm.pl
$ENV{'REVO_HOST'} = $SUBM_HOST;
$ENV{ADM_USER} = 'araneo';
$ENV{ADM_PASSWORD} = `tst/adm_pwd.sh`;


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

`rm -rf dict/tmp && mkdir -p dict/xml && mkdir -p dict/tmp`;
`ln -s \$(pwd)/../voko-grundo/dtd dict/`;
`bin/create_test_repo.sh /tmp && tst/adm_forigi_subm.sh`;


# transdonu registrita test-redaktanton en medivariablo,
# alie la testo fiaskos pro rifuzo de la redakto
my $redaktanto = $ENV{TEST_RETADRESO} || '_registrita_testredaktanto_@retavortaro.de';


# 2. preparo de TTT-testkliento
my $mech = Test::WWW::Mechanize->new();

# kapoj
$mech->add_header('Accept' => '*/*');

my $xmlTxt = << '~~~~~';
<?xml version="1.0"?><!DOCTYPE vortaro SYSTEM "../dtd/vokoxml.dtd"><vortaro>
<art mrk="$Id: kvin.xml,v 1.116 2021/06/22 19:02:35 revo Exp $">
<kap><ofc>*</ofc><rad>kvin</rad></kap>
<drv mrk="kvin.0"><kap><tld/></kap>
<snc><dif>Kvar kaj unu. Matematika simbolo 5:<ekz><tld/> kaj sep faras dek du
<fnt><bib>F</bib><lok>&FE; 12</lok></fnt>;</ekz>
</dif><ref tip="lst" cel="nombr.0o.MAT" lst="voko:nombroj" val="5">nombro</ref>
</snc></drv></art></vortaro>
~~~~~


note($xmlTxt);

forsendo($xmlTxt,'kvin','Forsendi artikolon \'kvin\'');
# $mech->scraped_id_like('malkonfirmo', qr/problemo kun la retpoŝta servo/,'Send-eraro');
# T8
$mech->scraped_id_like('konfirmo', qr/Bone/,'Konfirmo de submeto');

# ni nun ŝanĝas artikol-Id al erar.xml, kaj subemtas
# dufoje, la trakto de la unua fojo poste devus sukcesi, la
# dua fojo rifuziĝi per versikonflikto
$xmlTxt =~ s/\$Id.*\$/$id_erar/;
forsendo($xmlTxt,'erar','Unuafoje forsendi artikolon kiel \'erar\'');
# T17
$mech->scraped_id_like('konfirmo', qr/Bone/,'Konfirmo de submeto');

forsendo($xmlTxt,'erar','Duafoje forsendi artikolon kiel \'erar\'');
# T23
$mech->scraped_id_like('konfirmo', qr/Bone/,'Konfirmo de submeto');

# Nun ni provas trakti la submeton regule per processsubm.pl

#main::MAIN();
my @logged_events;

# Ni aldonas protokolon en liston por poste kontroli ĝin

$main::LOG->add(
    Log::Dispatch::Array->new(
        name      => 'test_array_logger',
        min_level => 'debug',
        array     => \@logged_events
    )
);

## note(Dumper($main::LOG->outputs())); #exit;

#$main::LOG->output('Log::Dispatch::Screen')->{stderr} = 1;
#stderr_like(
#    sub { main::MAIN() },
#    qr/Trovitaj novaj submetoj:.*desc: nur testo.*Ne valida artikolmarko.*sendas raportojn al redaktintoj.*Aktualigo de submeto.*ŝovas/,
#    "MAIN() informas pri submetoj, sendo de raportoj kaj fino"
#);

main::MAIN();

note(Dumper(@logged_events));

# T25
cmp_deeply( \@logged_events, superbagof( 
    # VAR1
    {
        'level' => 'info',
        'message' => re(qr/Trovitaj novaj submetoj: 3/)
    },
    # VAR5
    {
        'level' => 'info',
        'message' => re(qr/desc: nur testo/)
    },
    # VAR13
    {
        'level' => 'info',
        'message' => re(qr/En la ar\x{125}ivo ne trovi\x{11d}is la artikolo/)
    },
    # VAR26
    {
        'level' => 'info',
        'message' => re(qr/1 dosiero, 14 enmetoj\(\+\), 74 forigoj\(\-\)/s)
    },
    # VAR38
    {
        'level' => 'info',
        'message' => re(qr/La de vi sendita artikolo.*ne bazi\x{11d}as sur la aktuala arkiva versio/s)
    },
    # VAR41
    {
        'level' => 'info',
        'message' => re(qr/sendas raportojn al redaktintoj/)
    },
    {
        'level' => 'info',
        'message' => re(qr/Aktualigo de submeto.*stat: erar/)
    },
    # VAR50
    {
        'level' => 'debug',
        'message' => re(qr/attach:.*kvin\.xml/)
    },
    # VAR51
    {
        'level' => 'debug',
        'message' => re(qr/attach:.*erar\.xml/)
    },
    # VAR53
    {
        'level' => 'info',
        'message' => re(qr/\x{15d}ovas.*mailsend al/)
    }
) );

done_testing();
##########################

sub forsendo {
    my ($xml,$art,$testo) = @_;

    $mech->post_ok($SUBM_URL, 
        [
            art   => $art,
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
    # T2/10/18
    like(
        $mech->response->header('Content-Type'),
        qr{text/html;\s*charset=utf-?8}i,
        'Ĝusta enhavtipo (html, utf-8)'
    );

    # T3..T7/11..15/19..23
    $mech->title_is('vokosubmx', 'Titolo \'vokosubmx\' troviĝis');
    $mech->content_like(qr/<body>/, 'body...');
    $mech->content_like(qr/ni ne povas sendi al vi kopion/,'ne eblis sendi kopion');
    $mech->id_exists_ok('xml_err','Troviĝas alineo \'xml_err\'');
    $mech->id_exists_ok('ref_err','Troviĝas alineo \'ref_err\'');
}



