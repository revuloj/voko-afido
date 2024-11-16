#!/bin/bash
set -x

# FARENDA: legu var el config:
# var=$(cat /voko-afido.var_afido)
var=/var/afido
dict=/home/afido/dict

mkdir -p ${var}/tmp/mailatt
mkdir -p ${var}/tmp/xml
ln -s ${dict}/dtd ${var}/tmp/

#mkdir -p ${var}/log
mkdir -p ${var}/log/oldmail
mkdir -p ${var}/log/errmail
mkdir -p ${var}/log/prcmail

chown -R afido:users ${var}

