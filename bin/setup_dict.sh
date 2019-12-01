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

  git clone -q https://github.com/revuloj/revo-fonto.git ${dict}/revo-fonto
  chown -R afido.users ${dict}/revo-fonto
fi

if [ ! "$(git config --global user.email)" ]; then
  echo "Metante Revo-uzanton por Git..."

  git config --file ${dict}/revo-fonto/.git/config user.email "revo@reta-vortaro.de"
  git config --file ${dict}/revo-fonto/.git/config user.name "revo"
fi



