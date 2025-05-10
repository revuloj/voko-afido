#!/bin/bash

# Ni akiras la liston de redaktantoj kiel simpla teksto

basedir=${HOME}
etc=${basedir}/etc
redj=${etc}/voko.redaktantoj
timeout=60
retry=3

REVO_HOST="reta-vortaro.de"
url=https://${REVO_HOST}${ADM_URL}/redaktantoj.pl

# legu sekretojn...
ADM_USER=${ADM_USER}||${CGI_USER}||$(cat /run/secrets/voko-araneo.cgi_user)
ADM_PASSWORD=${ADM_PASSWORD}||${CGI_PASSWORD}||$(cat /run/secrets/voko-araneo.cgi_password)

# legu aktualan liston de redaktantoj
echo "${redj} <- ${url}" 
curl -o ${redj} --fail --user ${ADM_USER}:${ADM_PASSWORD} --max-time ${timeout} --retry ${retry} ${url}