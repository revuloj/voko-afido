#!/bin/bash
# FARENDA: legu var el config:
# var=$(cat /voko-afido.var_afido)
var=/var/afido

mkdir -p ${var}/tmp
mkdir -p ${var}/log
mkdir -p ${var}/log/oldmail
mkdir -p ${var}/log/errmail
chown -R afido.users ${var}