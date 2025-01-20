##### staĝo 1: certigu, ke vi antaŭe kompilis voko-grundo aŭ ŝargis de Github kiel pakaĵo

# VERSION povas esti ŝanĝita de ekstere per --build-arg, jam konsiderata en 'bin/eldono.sh kreo'
ARG VERSION=latest
FROM ghcr.io/revuloj/voko-grundo/voko-grundo:${VERSION} as grundo 
  # ni bezonos la enhavon de voko-grundo build poste por kopi jsc, stl, dok

# en ubuntu 20.04, 24.04 okazas problemoj pri JSON en JSON ĉe la GH-Api
FROM ubuntu:22.04

LABEL Maintainer="<diestel@steloj.de>"

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    openssh-server ca-certificates openssl rxp git cvs curl unzip patch jq \
    libjson-perl libtext-csv-perl libmime-tools-perl liblog-dispatch-perl \
    libnet-ssleay-perl libio-socket-ssl-perl libnet-smtp-ssl-perl libauthen-sasl-perl \
    libauthen-sasl-saslprep-perl libnet-smtp-tls-perl \
    liblwp-protocol-https-perl liblwp-useragent-determined-perl \
  && rm -rf /var/lib/apt/lists/* \
	&& mkdir -p /var/run/sshd

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

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

## RUN curl -k -LO https://github.com/revuloj/voko-grundo/archive/master.zip \
##   && unzip master.zip voko-grundo-master/dtd/* && rm master.zip && mkdir dict \
##   && ln -s /home/afido/voko-grundo-master/dtd  dict/dtd

COPY --from=grundo build/dtd/ dict/dtd

# se ni volas uzi la gastigan reton (network_mode: "host) por forsendi retpoŝton
# ni bezonas la eblecon difini alian servo-retpordon tie ĉi,
# ĉar 
#   network --driver host 
# ne kunfunkcias kun
#   run --publish gastiga:interna
ENV AFIDO_PORT=22

USER root
#EXPOSE 22

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/usr/sbin/sshd","-D","-p","${AFIDO_PORT}"]
