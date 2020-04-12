#!/bin/bash

basedir=/home/afido

cat /run/secrets/voko-afido.ssh_key.pub > ${basedir}/.ssh/authorized_keys

# unua klonado ankoraŭ kaŭzas problemojn pri la servilo-ŝlosilo, jen du priaj diskutoj:
# https://stackoverflow.com/questions/13363553/git-error-host-key-verification-failed-when-connecting-to-remote-repository
# https://stackoverflow.com/questions/18711794/warning-permanently-added-the-rsa-host-key-for-ip-address

## momente ni ne bezonas tion, ĉar ni uzas GITHUB_TOKEN anst. DEPLOY-KEY
##if [ ! -s ${basedir}/.ssh/known_hosts ]; then
##  gh_rsa=$(ssh-keyscan -t rsa github.com)
##
##  gh_fp=$(echo -e "${gh_rsa}" | ssh-keygen -lf -)
##  if [[ "${gh_fp}" == *"2048 SHA256:nThbg6kXUpJWGl7E1IGOCspRomTxdCARLviKw6E5SY8 github.com (RSA)"* ]]; then
##    echo -e "${gh_rsa}" >> ${basedir}/.ssh/known_hosts
##  fi  
##fi

chown -R afido.users ${basedir}/.ssh 
chmod 0700 ${basedir}/.ssh
chmod 0600 ${basedir}/.ssh/*

