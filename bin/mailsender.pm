use strict;

package mailsender;

use MIME::Entity;
use Net::SMTP::SSL;
use JSON;

my $mailsenderconf="/etc/mailsender.conf";
my $debug = 1;

sub smtp_connect {

    my $setup = read_conf();

    if ($setup) {

        my $smtps = Net::SMTP::SSL->new(
            $setup->{server}, 
            Port => $setup->{port},
            Debug => $debug,
        ) or warn "$!\n"; 
        $smtps->auth($setup->{user}, $setup->{password}) 
            or die "Saluto al retpoŝtilo malsukcesis!";
        return $smtps;
    }
}

sub smtp_quit {
    my $smtps = shift;
    $smtps->quit();
}

sub smtp_send {
    my ($smtps, $from, $to, $mailhandle) = @_;

    $smtps->mail($from);
    $smtps->to($to);
    $smtps->data();
    $smtps->datasend($mailhandle->as_string());
    $smtps->dataend();
}

sub read_conf {
    my $json_parser = JSON->new->allow_nonref;

  	unless (open CFG, "$mailsenderconf") {
		warn "Ne povis malfermi '$mailsenderconf': $!\n";
	}
	my $cfg = join('',<CFG>);
	close CFG;

    print substr($cfg,0,20),"...\n" if ($debug);

	unless ($cfg) {
		warn "Malplena SMTP-agordo '$mailsenderconf'";
		return;
	}

    my $parsed = $json_parser->decode($cfg);
	unless ($parsed) {
		warn "Sintaksa problemo? Ne eblis analizi enhavon de '$mailsenderconf'.\n";
		return;
	}

	return $parsed;	  
}
