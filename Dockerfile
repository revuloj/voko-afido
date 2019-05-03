FROM perl:slim
MAINTAINER <diestel@steloj.de>

# https://packages.debian.org/stretch/perl/

RUN apt-get update && apt-get install -y --no-install-recommends \
    rxp cvs patch fetchmail ssmtp openssl libemail-mime-perl \
	&& rm -rf /var/lib/apt/lists/*

COPY bin /usr/local/

RUN useradd -ms /bin/bash -u 1074 afido
WORKDIR /home/afido

USER afido:users


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
# docker run -v /pado/al/xml:revo/xml voko-vaneso redaktoservo.pl -a

