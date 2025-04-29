#!/bin/bash

# tuj finu se unuopa komando fiaskas 
# tio necesas por distingi sukcesan de malsukcesa testaro
set -e
set -x

docker_image="${1:-voko-afido:latest}"

# lanĉi la test-procezujon
docker run ${docker_image} 'bash -c "ls -l && ls -l dict &&\
   [ -f dict/dtd/vokoxml.dtd ] || exit 1 &&\
   perl -MMIME::Entity -MAuthen::SASL::Perl -MIO::Socket::SSL -e1 &&\
   perl -c /usr/local/bin/processgist.pl && perl -c /usr/local/bin/processsubm.pl &&\
   bash -n /usr/local/bin/afido &&\
   bash -n /usr/local/bin/aktualigu_gistojn.sh &&\
   bash -n /usr/local/bin/git-clone-repo.sh &&\
   bash -n /usr/local/bin/prenu_redaktantoliston.sh &&\
   bash -n /usr/local/bin/setup_env.sh &&\
   bash -n /usr/local/bin/setup_ssh.sh &&\
   bash -n /usr/local/bin/docker-entrypoint.sh &&\
   bash -n /usr/local/bin/prenu_gistojn.sh &&\
   bash -n /usr/local/bin/redaktoservo.sh &&\
   bash -n /usr/local/bin/setup_revo_loke.sh &&\
   bash -n /usr/local/bin/setup_var.sh &&\
   bash -n /usr/local/bin/forigu_malnovajn_gistojn.sh &&\
   bash -n /usr/local/bin/prenu_redaktantojn.sh &&\
   bash -n /usr/local/bin/setup_dict.sh &&\
   bash -n /usr/local/bin/setup_smtp.sh &&\
   bash -n /usr/local/bin/taga-resumo.sh "'