#!/usr/bin/perl

use strict; use warnings;
use utf8; use open ':std', ':encoding(UTF-8)';
use Test::More; 

#use lib('./cgi');
my $LIB ='./bin/perllib';

sub sintaks_kontrolo {
    my $script = shift;

    my $eligo = `perl -I$LIB -c $script 2>&1`;
    ok($? == 0, "Sintakskontrolo: $script") or diag($eligo);
}

# por kontroli (kaj korekti) sintakson de unuopa 
# oni povas uzi 
# perl -I./cgi/perllib -c cgi/<skripto...>.pl

sintaks_kontrolo("./bin/processmail.pl");
sintaks_kontrolo("./bin/processsubm.pl");

done_testing();
