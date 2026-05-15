# t/mein_test.t
use strict;
use warnings;
use Test::More; # tests => 2; 

use Encode qw(encode decode);

use lib('./bin');
require 'processmail.pl';

my $utf8 = 'eĥoŝanĝo ĉiuĵaŭde EĤOŜANGO ĈIUĴAŬDE';
my $art_id = '$Id: artiko.xml,v 1.52 2025/10/08 16:37:51 revo Exp $';

# Encode to Latin3 bytes
is( lat3_utf8( encode('iso-8859-3',decode('utf8',$utf8)) ),$utf8,'rekodigo lat3 utf8');
is( extract_article($art_id), 'artiko', 'ekstrakti dosiernomon el artikolmarko');
is( extract_version($art_id), '1.52', 'ekstrakti version el artikolmarko');


done_testing();
