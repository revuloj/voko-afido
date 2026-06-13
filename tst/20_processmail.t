#!/usr/bin/perl 

# (c) 2026 ĉe Wolfram Diestel
# tio testas bin/processmail.pl
# vi bezonas aktivan testmedion revo-medio/araneujo-t
# kaj agordon por uzi ties testan poŝtservon en /etc/mailsender.conf
# ${HOME}/etc/redaktantoj devas enhavi la retadreson de la
# testanto (mediovariablo $TEST_RETADRESO)

use strict;
use warnings;

use utf8; use open ':std', ':encoding(UTF-8)';
use Test::More; # tests => 2; 
use Test::Deep; 

use Encode qw(encode decode);
use Data::Dumper;
use Log::Dispatch::Array;

#$ENV{'DEBUG'} = 1; # necesas antaŭ require...!
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

#$main::CFG->{xml_dir}     = "$main::CFG->{dict_base}/xml";
$main::CFG->{git_dir}     = "/tmp/test-repo";
$main::CFG->{dok_dir}     = "$main::CFG->{dict_base}/dok";

$main::CFG->{mail_local}  = "$main::CFG->{tmp}/mail";
$main::CFG->{editor_file} = "$main::CFG->{dict_etc}/redaktantoj";
$main::CFG->{attachments} = "$main::CFG->{tmp}/mailatt/attchm".$$."_";

diag("processmail.pl-agordo: ".Dumper($main::CFG));


$process::CFG->{dict_home}= $ENV{'PWD'};
$process::CFG->{dict_base}= "$process::CFG->{dict_home}/dict"; # xml, dok, dt,
$process::CFG->{tmp}      = "$process::CFG->{dict_base}/tmp";
$process::CFG->{xml_temp} = "$process::CFG->{tmp}/xml";
$process::CFG->{git_dir}  = '/tmp/test-repo'; # "$CFG->{dict_base}/revo-fonto";
diag("process.pm-agordo: ".Dumper($process::CFG));

chomp(my $pwd = `pwd`);
my $mbox_file = "$pwd/dict/tmp/mail_test.mbox";
my $redaktanto = $ENV{TEST_RETADRESO} || '_registrita_testredaktanto_@retavortaro.de';

`rm -rf dict/tmp && mkdir -p dict/tmp/xml`;
`ln -s \$(pwd)/../voko-grundo/dtd dict/tmp/`;
`bin/create_test_repo.sh /tmp && perl tst/make_test_mbox.pl '$redaktanto' '$mbox_file'`;

#main::MAIN();
my @logged_events;

# Ni aldonas protokolon en liston por poste kontroli ĝin
$main::LOG->add(
    Log::Dispatch::Array->new(
        name      => 'test_array_logger',
        min_level => 'debug',
        array     => \@logged_events, 
    )
);

note(Dumper($main::LOG->outputs())); #exit;
#$main::LOG->output('Log::Dispatch::Screen')->{stderr} = 1;
#stderr_like(
#    sub { main::MAIN() },
#    qr/Trovitaj novaj submetoj:.*desc: nur testo.*Ne valida artikolmarko.*sendas raportojn al redaktintoj.*Aktualigo de submeto.*ŝovas/,
#    "MAIN() informas pri submetoj, sendo de raportoj kaj fino"
#);

$main::ARGV[0] = "$mbox_file";
main::MAIN();

note(Dumper(@logged_events));

cmp_deeply( \@logged_events, superbagof( 
#    {
#        'level' => 'info',
#        'message' => re(qr/rsync/)
#    },
    {
        'level' => 'info',
        'message' => re(qr/Spamisto/)
    },
    {
        'level' => 'info',
        'message' => re(qr/erara mesagho sekurigita al.*\/mailerr/)
    },
    {
        'level' => 'info',
        'message' => re(qr/Redaktanto/)
    },
    {
        'level' => 'info',
        'message' => re(qr/nova artikolo: nov/)
    },
    {
        'level' => 'info',
        'message' => re(qr/shanghoj: nova artikolo/)
    },    
    {
        'level' => 'info',
        'message' => re(qr/KONFIRMO:.*nova artikolo.*1 dosiero, 32 enmetoj.*create mode 100644 revo\/nov.xml/s)
    },
    {
        'level' => 'info',
        'message' => re(qr/artikolo: \$Id: erar.xml,v 1.47 [\d\/]{10} [\d:]{8} revo Exp \$/)
    },    
    # VAR33
    {
        'level' => 'info',
        'message' => re(qr/KONFIRMO:.*1 dosiero, 19 enmetoj\(\+\), 61 forigoj\(\-\)/s)
    },
    #...VAR47
    {
        'level' => 'info',
        'message' => re(qr/ERARO.*La de vi sendita artikolo.*sur la aktuala arkiva versio.*erar\.xml,v 1\.48.*Bonvolu preni aktualan version/s)
    },
    {
        'level' => 'info',
        'message' => re(qr/elsendas raportojn\.\.\./)
    },
    #VAR49
#    {
#        'level' => 'info',
#        'message' => re(qr/.*Saluton.*Jen raporto pri via\(j\) sendita\(j\) artikolo\(j\).*nova artikolo.*KONFIRMO.*19 enmetoj.*ERARO.*arkiva versio/as)
#},
#    {
#        'level' => 'info',
#        'message' => code(sub {
#            #my $raw_bytes = shift;
#            
#            # Wir wandeln die rohen Bytes des Logs in echten Unicode-Text um:
#            my $unicode_string = shift; #Encode::decode('UTF-8', $raw_bytes);
#            
#            # Jetzt matcht JEDER ganz normale Regex ohne irgendwelche '/a'-Tricks!
#            return $unicode_string =~ /Saluton!/ #.*Jen raporto pri via\(j\) sendita\(j\) artikolo\(j\).*shanghoj:/as;
#        }),
#    },    
    {
        'level' => 'info',
        'message' => re(qr/pu.*ojn al git\.\.\./s)
    },
    {
        'level' => 'info',
        'message' => re(qr/mailerr al/s)
    },
    {
        'level' => 'info',
        'message' => re(qr/mailsend al/s)
    },
));

my $saluton;
for my $l (@logged_events) {
    if ( $l->{message} =~ /Saluton/ ) {
        $saluton = 1;
        note("SALUTON\n");
        like($l->{message},qr/Saluton!.*Jen raporto pri via\(j\) sendita\(j\) artikolo\(j\)/s);
        like($l->{message},qr/nova artikolo.*KONFIRMO.*19 enmetoj.*ERARO.*arkiva versio/s);
    }
}

is($saluton,1);

done_testing();
