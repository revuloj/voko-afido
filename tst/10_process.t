# t/mein_test.t
#use strict;
use warnings;
use Test::More; # tests => 2; 
use Test::Deep;
use Data::Dumper;
use JSON;
use utf8; use open ':std', ':encoding(UTF-8)';

use lib('./bin');
use process qw($CFG);

# iom da reagordo por loka testo...
chomp(my $pwd = `pwd`);
local $CFG->{dict_home} = $pwd;
local $CFG->{dict_base}= "$CFG->{dict_home}/dict"; # xml, dok, dt,
local $CFG->{tmp}      = "$CFG->{dict_base}/tmp";
local $CFG->{xml_temp} = "$CFG->{tmp}/xml";
local $CFG->{git_dir}  = 'test-repo'; # "$CFG->{dict_base}/revo-fonto";
diag(Dumper($CFG));

# ni supozas ke DTD-dosieroj troviĝas ĉe ../voko-grundo/dtd
# se ne vi devas mane ligi/kopii ilin al dict/tmp/dtd
`mkdir -p dict/tmp && rm -rf dict/tmp/* && ln -s \$(pwd)/../voko-grundo/dtd dict/tmp/`;

my $USER = $ENV{'USER'};
my $JSON = <<'EOJ';
[
    {"msg": "mesaĝo al mi mem", "code": 123}
]
EOJ
my $CSV = <<'EOC';
nombro;unu;du;tri
unu;1;11;111
du;2;22;222
tri;3;33;333
naŭ;9;99;999
EOC

my $json_parser = JSON->new->pretty;

`bin/create_test_repo.sh`;
# Encode to Latin3 bytes

is( process::my_name(),$USER,'my_name()' );
like( process::sys_run('pwd'),qr/voko-afido$/,'sys_run(pwd)' );
like( process::timestamp(), qr/^\d{8}_\d{6}$/,'timestamp()' );
is( process::trim("\n abc \t"),'abc','trim()' );

like( process::read_file('test-repo/revo/artefakt.xml'),qr/<\?xml/,'read_file(..artefkakt.xml)' );

# skribi $JSON kiel ordinara teskto kaj provi enlegi kiel json
ok( process::write_file(">",'test-repo/test.json',$JSON), 'write_file(test-repo/test.json)' );
my $json = process::read_json_file('test-repo/test.json');
note("JSON:\n".Dumper($json));

cmp_deeply(
        $json,
        superbagof({
            'msg' => "mesa\x{11d}o al mi mem",
            'code' => 123
        }),
        "(1) JSON enhavas msg kaj code"
    );

# nun ni reskribas per write_json_file kaj legas denove
ok( process::write_json_file(">",'test-repo/test.json',$json), 'write_json_file(test-repo/test.json)' );
my $json1 = process::read_json_file('test-repo/test.json');
note("JSON:\n".Dumper($json1));

cmp_deeply(
        $json1,
        superbagof({
            'msg' => "mesa\x{11d}o al mi mem",
            'code' => 123
        }),
        "(2) JSON enhavas msg kaj code"
    );

my @csv = process::csv2arr($CSV);
note("CSV:\n".Dumper(@csv));

cmp_deeply(
        \@csv,
        superbagof({
            'nombro' => "unu",
            'unu'    => '1',
            'du'     => '11',
            'tri'    => '111'
        },
        {
            'nombro' => "na\x{16d}",
            'unu'    => '9',
            'du'     => '99',
            'tri'    => '999'
        }),
        "CSV enhavas rikordojn por 'unu' kaj 'na\x{16d}'"
    );

is( process::rep_str({
    senddato => '2026-01-01',
    artikolo => 'artefakt',
    rezulto  => 'konfirmo',
    mesagho  => 'artikolo akceptita'
    }), "senddato: 2026-01-01\nartikolo: artefakt\nKONFIRMO: artikolo akceptita\n", 'rep_str(...)' );
#like( )

`mkdir -p $CFG->{xml_temp}`;
`cp test-repo/revo/*.xml $CFG->{xml_temp}/`;
ok(!process::checkxml('artefakt',"$CFG->{xml_temp}/artefakt.xml",0),"Kontrolo de artefakt.xml ne donas erarojn");

# doni plenan identigilon al ĝi
`echo "testshangho" > $CFG->{xml_temp}/shangho.txt`;
ok( process::init_ver("$CFG->{xml_temp}/artefakt.xml","$CFG->{xml_temp}/shangho.txt"), "Identigilo al artefakt.xml" );

like( process::get_art_id("$CFG->{xml_temp}/artefakt.xml"),qr/^\$Id: artefakt.xml,v 1\.1 [\d\/]{10} [\d:]{8} .*\$$/,"Ni povas ekstrakti Id 1.1 de artefakt.xml" );

ok( process::incr_ver("$CFG->{xml_temp}/artefakt.xml","$CFG->{xml_temp}/shangho.txt"), "Versialtigo al artefakt.xml" );

like( process::get_art_id("$CFG->{xml_temp}/artefakt.xml"),qr/^\$Id: artefakt.xml,v 1\.2 [\d\/]{10} [\d:]{8} .*\$$/,"Ni povas ekstrakti Id 1.2 de artefakt.xml" );


like(process::sys_run_err('rxp','-Vs','dict/tmp/xml/erar.xml'),qr/^Warning: Required attribute mrk for element drv is not present/,"Kontrolo de erar.xml per rxp donas erarojn");

#Warning: Required attribute mrk for element drv is not present
# in unnamed entity at line 10 char 6 of file://./dict/tmp/xml/erar.xml
#Warning: Start tag for undeclared element sncx
# in unnamed entity at line 13 char 8 of file://./dict/tmp/xml/erar.xml
#Warning: Content model for drv does not allow element sncx here
# in unnamed entity at line 13 char 8 of file://./dict/tmp/xml/erar.xml
#Error: Mismatched end tag: expected </sncx>, got </snc>
# in unnamed entity at line 42 char 8 of file://./dict/tmp/xml/erar.xml

my $errors = process::checkxml('erar',"$CFG->{xml_temp}/erar.xml",0);
diag($errors);
like($errors,qr/^Warning: Required attribute mrk for element drv is not present/,"Kontrolo de erar.xml per checkxml donas erarojn");

like( process::xml_context($errors,"$CFG->{xml_temp}/erar.xml"),qr/10: <drv>/,"Kunteksto de la unua eraro" );

my ($out,$err) = process::git_cmd(qw(/usr/bin/git log -1));
like( $out, qr/commit.*Author:.*Date:.*v3/s, "Git log...");

done_testing();
