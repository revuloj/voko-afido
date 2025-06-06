use strict;

package mailsender;

#use MIME::Entity;
use Net::SMTP;
use Authen::SASL;
use JSON;
#use Data::Dumper;

my $mailsenderconf="/etc/mailsender.conf";
my $debug = 0;
my $verbose = 0;

if ($debug) {
    $IO::Socket::SSL::DEBUG=3;
}

sub smtp_connect {

    my $setup = read_conf();

    if ($setup) {

        # vd https://www.iana.org/assignments/sasl-mechanisms/sasl-mechanisms.xhtml
        # post forigo de *-MD5 restas PLAIN (eble LOGIN?)
        my $sasl = Authen::SASL->new(
            mechanism => 'PLAIN',
            debug => $debug,
            callback => {
                pass => $setup->{password},
                user => $setup->{user},
            }
        );

        my $smtps = Net::SMTP->new(
            $setup->{server}, 
            Port => $setup->{port},
            Debug => $debug,
        ) or warn "$!\n"; 

        if ($smtps) {
            if ($setup->{port} eq 587) {
                $smtps->starttls();
            }

            #$smtps->auth($setup->{user}, $setup->{password}) 
            if ($setup->{password}) {
                my $authzd = $smtps->auth($sasl);
                unless ($authzd) {
                    #print "SASL: ",Dumper($sasl);
                    die "Saluto al retpoŝtilo malsukcesis!";
                }
                #print "SASL: ",Dumper($sasl) if ($debug);
            }
            return $smtps;
        }
    } else {
        die "Agordo por retpoŝt-sendo mankas!";
    }
}

sub smtp_quit {
    my $smtps = shift;
    $smtps->quit();
}

sub smtp_send {
    my ($smtps, $from, $to, $mailhandle) = @_;

    # nur por sencimigo, alie ni devus kaŝi partojn de la retpoŝtadresoj...
    print "send from <$from> to <$to>\n" if ($debug);

    $smtps->mail($from);
    $smtps->to($to);
    $smtps->data();
    $smtps->datasend($mailhandle->as_string());
    $smtps->dataend();

    return 1;
}

sub read_conf {
    my $json_parser = JSON->new->allow_nonref;

  	unless (open CFG, "${mailsenderconf}") {
		warn "Ne povis malfermi '${mailsenderconf}': $!\n";
	}
	my $cfg = join('',<CFG>);
	close CFG;

	unless ($cfg) {
		warn "Malplena SMTP-agordo '${mailsenderconf}'";
		return;
	}
    print substr($cfg,0,20),"...\n" if ($debug);

    my $parsed = $json_parser->decode($cfg);
	unless ($parsed) {
		warn "Sintaksa problemo? Ne eblis analizi enhavon de '${mailsenderconf}'.\n";
		return;
	}

	return $parsed;	  
}

1;
