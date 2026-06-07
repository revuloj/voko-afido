use strict;

package mailsender;

#use MIME::Entity;
use Net::SMTP;
use IO::Socket::SSL;
use Authen::SASL;
use JSON;
use Encode qw(is_utf8);

#use Data::Dumper;

my $mailsenderconf="/etc/mailsender.conf";
my $debug = 0;
my $timeout = 120; $timeout = 10 if ($debug);
my $verbose = 0;

if ($debug) {
    $IO::Socket::SSL::DEBUG=3;
}

sub smtp_connect {

    my $setup = read_conf();

    if ($setup) {


        my $smtps = Net::SMTP->new(
            $setup->{server}, 
            Port => $setup->{port},
            Debug => $debug,
        ) or warn "$!\n"; 

        if ($smtps) {
            if ($setup->{port} eq 587) {
                $smtps->starttls() or die "TLS-saluto fiaksis: $!\n";
            # ni testas evtl. loke per 1587 anstataŭ 587
            } elsif ($setup->{port} eq 1587) {
                $smtps->starttls(
                    # uzante memkreitajn TLS-atestilojn ni rezignu pri valideckontrolo
                    SSL_verify_mode => SSL_VERIFY_NONE
                ) or die "TLS-saluto fiaksis: $!\n";
            }

            #$smtps->auth($setup->{user}, $setup->{password}) 
            if ($setup->{password}) {

                # vd https://www.iana.org/assignments/sasl-mechanisms/sasl-mechanisms.xhtml
                # post forigo de *-MD5 restas PLAIN (eble LOGIN?)
                my $sasl = Authen::SASL->new(
                    mechanism => 'PLAIN',
                    debug => $debug,
                    timeout => $timeout,
                    callback => {
                        pass => $setup->{password},
                        user => $setup->{user},
                    }
                );

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

    $smtps->mail($from) or die "Ne povas komenci novan restpoŝton: $!\n";

    if ( $smtps->to($to) ) {
        unless ($smtps->data()) {
            die "Eraro kiam sendante komandon DATA: $!\n";
            return;
        }
        
        $smtps->datasend($mailhandle->as_string());

        unless ($smtps->dataend()) {
            print "Eraro ĉe forsendo de la mesaĝo: ", $smtps->message();
            return;
        }
        return 1;
    }
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
