#!/bin/bash

#set -x

# FARENDA: legu var el config:
# var=$(cat /voko-afido.var_afido)
var=/var/afido
grundo=/home/afido/voko-grundo

mkdir -p ${var}/tmp/mailatt
mkdir -p ${var}/tmp/xml

if [ ! -h ${var}/tmp/dtd ]; then
  ln -s -f ${grundo}/dtd ${var}/tmp/
fi

#mkdir -p ${var}/log
mkdir -p ${var}/log/oldmail
mkdir -p ${var}/log/errmail
mkdir -p ${var}/log/prcmail

chown -R afido:users ${var}

