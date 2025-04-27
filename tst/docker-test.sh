#!/bin/bash

# tuj finu se unuopa komando fiaskas 
# tio necesas por distingi sukcesan de malsukcesa testaro
set -e
set -x

docker_image="${1:-voko-afido:latest}"

# lanĉi la test-procezujon
docker run ${docker_image} 'bash -c "ls -l && ls -l dict &&\
   [ -f dict/dtd/vokoxml.dtd ] || exit 1 &&\
   perl -MMIME::Entity -MAuthen::SASL::Perl -MIO::Socket::SSL -e1"'