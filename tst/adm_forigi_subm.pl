#!/usr/bin/perl

# (c) 2026 ĉe Wolfram Diestel
# laŭ GPL 2.0
#
# Tion ni kopios al araneujotesto_araneo:/cgi-bin/admin/ por forigi ĉiujn submetojn
# antaŭ fari testojn

use warnings; use strict; use utf8;

use CGI qw(:standard); use CGI::Carp qw(fatalsToBrowser);
use DBI();

# propraj perl moduloj estas en:
use lib("/hp/af/ag/ri/files/perllib");
# por testi loke vi povas aldoni simbolan ligon: ln -s /home/revo/voko/cgi/perllib /hp/af/ag/ri/files/

use revodb;

my $debug = 0; #0|1;

print header(-type => 'text/plain', -charset => 'utf-8');

my $dbh = revodb::connect();
forigu_submetojn();
$dbh->disconnect() or die "Malkonekto de la datumbazo ne funkciis: $!\n";


sub forigu_submetojn {

    $dbh->{RaiseError} = 1;

    eval { 
        my $sql = $dbh->prepare("DELETE FROM submeto;");
        $sql->execute();
    } or do {     
        warn "Datumbaza eraro: $@\n"; 
        # eval { $dbh->rollback() }; # in case rollback() fails 
        # cleanup here 
    };

    return;
}