#!/bin/bash
set -x

dict=/home/afido/dict

mkdir -p $dict/xml
chown -R afido.users ${dict}

#if [ ! -e ${dict}/xml ]; then 
##if [ ! "$(ls -A ${dict}/xml)" ]; then
##  echo "Elverŝante aktualajn XML-dosierojn al xml/..."
##  mkdir -p ${dict}/xml
##  #CVSROOT=$(pwd)/cvsroot 
##  cvs co -A -d ${dict}/xml revo 
##  chown -R afido.users ${dict}
##fi

cd ${dict}
su afido
if [[ ! $(ls -A ${dict}/revo-fonto) ]]; then
    # vi povas antaŭdifini ekz.:
    # GIT_REPO_REVO=https://github.com/revuloj/revo-fonto-testo.git
    # por preni la fontojn el Git-arĥivo
    echo "Elverŝante aktualajn XML-dosierojn el git@github.com:$GIT_REPO_REVO al revo-fonto/..."
    if [[ ! -z "$GIT_REPO_REVO" ]]; then
        #?? git clone --progress $GIT_REPO_REVO revo-fonto
        # cd $dict
        #git clone -q ssh://git@github.com/$GIT_REPO_REVO ${dict}/revo-fonto
        git clone -q git@github.com:$GIT_REPO_REVO ${dict}/revo-fonto
        #chown -R afido.users ${dict}/revo-fonto
    fi
fi

if [ ! "$(git config --global user.email)" ]; then
  echo "Metante Revo-uzanton por Git..."

  git config --file ${dict}/revo-fonto/.git/config user.email "RetaVortaro@steloj.de"
  git config --file ${dict}/revo-fonto/.git/config user.name "reta-vortaro"
fi



