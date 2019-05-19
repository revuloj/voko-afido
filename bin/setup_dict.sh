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

