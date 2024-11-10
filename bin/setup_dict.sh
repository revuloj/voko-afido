#!/bin/bash
set -x

dict=/home/afido/dict

mkdir -p $dict/xml
mkdir -p $dict/tmp
chown -R afido:users ${dict}

