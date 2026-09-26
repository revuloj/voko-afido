#!/bin/bash

basedir=/home/afido

# aldonu servilo-ŝlosilon por github.com

# se unua klonado ankoraŭ kaŭzas problemojn pri la servilo-ŝlosilo, jen du priaj diskutoj:
# https://stackoverflow.com/questions/13363553/git-error-host-key-verification-failed-when-connecting-to-remote-repository
# https://stackoverflow.com/questions/18711794/warning-permanently-added-the-rsa-host-key-for-ip-address

## if [ ! -s ${basedir}/.ssh/known_hosts ]; then
##   #touch ${basedir}/.ssh/known_hosts
##   gh_rsa=$(ssh-keyscan -t rsa github.com)
##   gh_ed=$(ssh-keyscan -t ed25519 github.com)
## 
##   gh_fp=$(echo -e "${gh_rsa}" | ssh-keygen -lf -)
##   if [[ "${gh_fp}" == *"3072 SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s github.com (RSA)"* ]]; then
##     echo -e "${gh_rsa}" >> ${basedir}/.ssh/known_hosts
##   fi  
## 
##   gh_fp2=$(echo -e "${gh_ed}" | ssh-keygen -lf -)
##   if [[ "${gh_fp2}" == *"256 SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU github.com (ED25519)"* ]]; then
##     echo -e "${gh_ed}" >> ${basedir}/.ssh/known_hosts
##   fi  
## 
## fi

if [ -f "/run/secrets/voko-afido.ssh_key.pub" ]; then
    cat /run/secrets/voko-afido.ssh_key.pub > ${basedir}/.ssh/authorized_keys
fi

chown -R afido:users ${basedir}/.ssh 
chmod 0700 ${basedir}/.ssh
chmod 0600 ${basedir}/.ssh/*
