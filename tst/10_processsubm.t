# t/mein_test.t
use strict;
use warnings;
use Test::More; # tests => 2; 

use Encode qw(encode decode);

use lib('./bin');
use process qw(sys_run my_name timestamp trim);
require 'processsubm.pl';

my $utf8 = 'eĥoŝanĝo ĉiuĵaŭde EĤOŜANGO ĈIUĴAŬDE';
my $art_id = '$Id: artiko.xml,v 1.52 2025/10/08 16:37:51 revo Exp $';

# Encode to Latin3 bytes
is( extract_article({},$art_id), 'artiko', 'ekstrakti dosiernomon el artikolmarko');

done_testing();
