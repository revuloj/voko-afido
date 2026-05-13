#!/usr/bin/perl

# necesas antaŭe instali perl-critic, ekz-e per 
# sudo apt install libperl-critic-perl libtest-perl-critic-perl

use strict; use warnings;
use Test::More; use Test::Perl::Critic (-severity=>3, -verbose => '%f:%l:%c (S%s) %m');

# vi povas unuopan dosieron testi kaj vidi la avertojn per
# perlcritic --severity 3 --verbose 8 cgi/<skripto>.pl

all_critic_ok('bin');

