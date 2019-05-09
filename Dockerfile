FROM perl:slim
MAINTAINER <diestel@steloj.de>

# https://packages.debian.org/stretch/perl/

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    openssh-server rxp cvs patch ssmtp libemail-mime-perl \
	&& mkdir -p /var/run/sshd && rm -rf /var/lib/apt/lists/*

COPY bin/* /usr/local/bin/
#ENV PATH "$PATH:/usr/local/bin"

RUN useradd -ms /bin/bash -u 1074 afido
WORKDIR /home/afido

###USER afido:users


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

###ENTRYPOINT ["docker-entrypoint.sh"]
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
# echo "M14P$svort0" > ~/etc/secrets/voko-afido.pop3_password -
# sudo chmod 400 ~/etc/secrets/voko-afido* && chown 1074 ~/etc/secrets/voko-afido*
#
# docker run -it -v ~/etc/secrets:/run/secrets voko-afido bash

USER root
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
