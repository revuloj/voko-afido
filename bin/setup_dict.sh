#!/bin/bash
set -x

dict=/home/afido/dict
#chown -R afido.users /home/afido

#if [ ! -e ${dict}/xml ]; then 
if [ ! "$(ls -A ${dict}/xml)" ]; then
  echo "Elverŝante aktualajn XML-dosierojn al xml/..."
  mkdir -p ${dict}/xml
  #CVSROOT=$(pwd)/cvsroot 
  cvs co -A -d ${dict}/xml revo 
  chown -R afido.users ${dict}
fi

if [ ! "$(ls -A ${dict}/revo-fonto)" ]; then
  echo "Elverŝante aktualajn XML-dosierojn per Git al revo-fonto/..."

  git clone -q git@github.com:revuloj/revo-fonto.git ${dict}/revo-fonto
  chown -R afido.users ${dict}/revo-fonto
fi

if [ ! -s /home/afido/.ssh/known_hosts ]; then
  gh_rsa=$(ssh-keyscan -t rsa github.com)
  gh_fp=$(echo -e "${gh_rsa}" | ssh-keygen -lf -)
  if [[ "${gh_fp}" == *"2048 SHA256:nThbg6kXUpJWGl7E1IGOCspRomTxdCARLviKw6E5SY8 github.com (RSA)"* ]]; then
    echo -e "${gh_rsa}" >> /home/afido/.ssh/known_hosts

    chown afido.users /home/afido/.ssh/known_hosts
    chmod 600 /home/afido/.ssh/known_hosts
  fi  
fi

if [ ! "$(git config --global user.email)" ]; then
  echo "Metante Revo-uzanton por Git..."

  git config --file ${dict}/revo-fonto/.git/config user.email "RetaVortaro@steloj.de"
  git config --file ${dict}/revo-fonto/.git/config user.name "reta-vortaro"
fi



