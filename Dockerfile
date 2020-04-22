FROM ubuntu:18.04
#FROM perl:5.24-slim-threaded
#FROM perl:slim
LABEL Maintainer="<diestel@steloj.de>"

# https://packages.debian.org/stretch/perl/

## https://hub.docker.com/r/jjmerelo/perl-io-socket-ssl/dockerfile
#FROM perl:5.24-slim-threaded
#LABEL version="1.0" maintainer="JJ Merelo <jjmerelo@GMail.com>" perl5version="5.24"
#
## Set up dir and download modules
#RUN chmod o+r /etc/resolv.conf
#RUN mkdir /test && apt-get update && apt-get install -y git curl libio-socket-ssl-perl libnet-ssleay-perl
#RUN perl --version
#
## Will run this
#ENTRYPOINT ["perl", "-I/usr/local/lib -I/usr/share/perl5 -I/usr/lib/x86_64-linux-gnu/perl5/5.24/"] 

#RUN chmod o+r /etc/resolv.conf
#RUN mkdir /test && apt-get update && apt-get install -y git curl libio-socket-ssl-perl libnet-ssleay-perl
#RUN perl --version

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    openssh-server ca-certificates openssl rxp git cvs curl unzip patch jq \
    libjson-perl libmime-tools-perl liblog-dispatch-perl \
    libnet-ssleay-perl libio-socket-ssl-perl libnet-smtp-ssl-perl libauthen-sasl-perl \
    libauthen-sasl-saslprep-perl libnet-smtp-tls-perl\
  && rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /var/run/sshd 


#  && cpanm install MIME::Entity Authen::SASL::Perl \

# https://rt.cpan.org/Public/Bug/Display.html?id=128717

# ssmtp
# ??   libauthen-sasl-saslprep-perl libnet-smtp-tls-perl libgssapi-perl
# perl -MAuthen::SASL::Perl -e1
# cpan -i Authen::SASL::Perlsudo 
# dh-make-perl –install –cpan Foo::Bar
# https://serverfault.com/questions/815649/how-to-do-an-unattended-silent-cpan-install-setup

COPY bin/* /usr/local/bin/
#ENV PATH "$PATH:/usr/local/bin"

RUN useradd -ms /bin/bash -u 1074 afido && mkdir -p /home/afido/.ssh
WORKDIR /home/afido
COPY --chown=afido:afido ssh/* .ssh/
COPY --chown=afido:afido etc/* etc/

###USER afido:users

RUN curl -k -LO https://github.com/revuloj/voko-grundo/archive/master.zip \
  && unzip master.zip voko-grundo-master/dtd/* && rm master.zip && mkdir dict \
  && ln -s /home/afido/voko-grundo-master/dtd dict/dtd

# farenda:
#
# agordu fetchmail per .fetchmailrc
# poll reta-vortaro.de proto pop3 user "<user>" password <password> sslproto TLS1 sslcertpath /home/revo/etc/certs
# automate elŝutu atestilojn (certs) laŭeble
# uzu entrypoint.sh por tio
#
# ebligu difini poŝtfakon por sendi kune kun uzanto+pasvorto
# per variabloj (env), 
# vd. https://stackoverflow.com/questions/26215021/configure-sendmail-inside-a-docker-container
# por diskuti kiel sendi retpoŝton el docker-procesumo
# ssmtp: https://linuxundich.de/gnu-linux/system-mails-ohne-einen-mail-server-mit-ssmtp-verschicken/
#
# la interŝanĝo de XML-dosieroj kun la redaktoservo okazu per komuna dosierujo revo/xml
# docker run -v /pado/al/xml:revo/xml voko-afido redaktoservo.pl -a


#ENTRYPOINT ["echo","$PATH"]

#CMD ["perl","processmail.pl"]

# Por teste eniri la procesumon unuope vi devas aldoni sekretojn ekz. tiel:
# 
# mkdir -p ~/etc/secrets
# echo "smtp.provizanto.org" > ~/etc/secrets/voko-afido.smtp_server 
# echo "redaktoservo@provizanto.org" > ~/etc/secrets/voko-afido.smtp_user
# echo "M14P$svort0" > ~/etc/secrets/voko-afido.smtp_password -
# echo "pop3.provizanto.org" > ~/etc/secrets/voko-afido.pop3_server -
# echo "redaktoservo@provizanto.org" > ~/etc/secrets/voko-afido.pop3_user -
# echo "M14P4$svort0" > ~/etc/secrets/voko-afido.pop3_password -
# sudo chmod 400 ~/etc/secrets/voko-afido* && chown 1074 ~/etc/secrets/voko-afido*
#
# docker run -it -v ~/etc/secrets:/run/secrets voko-afido bash

USER root
EXPOSE 22
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]
