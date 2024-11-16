#!/bin/bash
set -x

dict=/home/afido/dict
grundo=/home/afido/voko-grundo

mkdir -p ${dict}/xml
mkdir -p ${dict}/tmp
ln -s ${grundo}/dtd ${dict}/tmp/

chown -R afido:users ${dict}

