#!/bin/bash

#set -x

dict=/home/afido/dict
grundo=/home/afido/voko-grundo

mkdir -p ${dict}/xml
mkdir -p ${dict}/tmp

if [ ! -h ${dict}/tmp/dtd ]; then
  ln -s ${grundo}/dtd ${dict}/tmp/
fi

chown -R afido:users ${dict}

