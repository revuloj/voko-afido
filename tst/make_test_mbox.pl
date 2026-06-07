#!/usr/bin/perl

use strict;
use warnings;
use utf8; #use open ':std', ':encoding(UTF-8)';

use MIME::Entity;

#use MIME::Tools; MIME::Tools->bootstring("debug");

use Encode qw(encode);
use URI::Escape qw(uri_escape_utf8);

my $from_addr = "Redaktanto <${ARGV[0]}>";
my $mbox_file = $ARGV[1] || './mail_test.mbox';
my $id_erar = '$Id: erar.xml,v 1.47 2025/03/14 06:18:12 revo Exp $';

open my $MBOX, '>', $mbox_file
  or die "Ne eblis krei $mbox_file: $!\n";
binmode($MBOX, ':raw');  

my $from_spamisto = 'Spamisto <spamisto@example.com>';
my $redaktilo_from = 'redaktilo@reta-vortaro.de';

my $subject_base = 'ReVo-testo';
chomp(my $timestamp = `date`);

my $XML = <<'EON';
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

# =========================================================================
# Spam-mesaĝo
# =========================================================================
my $msg_spam = MIME::Entity->build(
    From    => $from_spamisto,
    Subject => "$subject_base - spamo",
    Date    => $timestamp,
    Type    => 'text/plain; charset=utf-8',
    Data    => [
        "SPAM SPAM SPAM\nSPAM SPAM SPAM\n"
    ]
);


# =========================================================================
# Nova artikolo kiel simpla teksto
# =========================================================================
my $msg_plain = MIME::Entity->build(
    From    => $from_addr,
    Subject => "$subject_base - simpla teksto",
    Date    => $timestamp,
    Type    => 'text/plain; charset=utf-8',
    Data    => [
        "aldonu: nov\n\n".$XML
    ]
);

# =========================================================================
# TTT-formularo (URL-kodita)
# =========================================================================

my $shangho = uri_escape_utf8("neniu ŝanĝo"); 
$XML =~ s/\$Id.*\$/$id_erar/;
my $xml  = uri_escape_utf8($XML);           
my $form_data = "komando=redakto&shangho=$shangho&teksto=$xml";


my $msg_form = MIME::Entity->build(
    From    => 	$redaktilo_from,
    'Reply-To' => $from_addr,
    Subject => "$subject_base - URL-kodita formularo",
    Date    => $timestamp,
    Type    => 'application/x-www-form-urlencoded',
    Encoding   => '8bit',
    #InCore     => 1,
    Data    => [ $form_data ]
);

# =========================================================================
# Plurparta mesaĝo
# =========================================================================
my $msg_multi = MIME::Entity->build(
    From    => $from_addr,
    Subject => "$subject_base - plurparta mesagho",
    Date    => $timestamp,
    InCore  => 1,
    Type    => 'multipart/mixed'
);

# Parto 1: La komando
my $part1_data = encode('UTF-8', "redaktu:\nkion mi ŝanĝis, tio estas sekreto.");

#print "PART1: $part1_data\n";

$msg_multi->attach(
    Type => 'text/plain; charset=utf-8',
    InCore  => 1,
    Encoding => '8bit',
    Data => [ $part1_data ] #"redaktu:\nkion mi ŝanĝis, tio estas sekreto." ] #$part1_data ]
);

# Parto 2: La XML-dosiero
my $part2_data = encode('UTF-8', $XML);
#print "PART2: $part2_data\n";

$msg_multi->attach(
    Type => 'application/xml; charset=utf-8',
    InCore  => 1,
    Encoding => '8bit',
    Data => [ $part2_data ]
);

# =========================================================================
# KUNFANDO en Unix-Mbox formaton (kun la linio "From ...")
# =========================================================================
foreach my $msg ($msg_spam, $msg_plain, $msg_form, $msg_multi) {
    # Ĉiu retpoŝto en Mbox devas komenciĝi per la "From " linio (sen dupunkto)
    my $from = $msg->head->get('From');
    print $MBOX "From $from $timestamp\n";
    $msg->print($MBOX);
    print $MBOX "\n\n"; # Spaco inter la mesaĝoj
}

close $MBOX;
print "Sukcese kreis la testan dosieron '$mbox_file' kun la 3 formatoj!\n";