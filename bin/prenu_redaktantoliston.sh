#!/bin/bash

# Ni akiras la liston de redaktantoj kiel simpla teksto

basedir=${HOME}
etc=${basedir}/etc
redj=${etc}/voko.redaktantoj
timeout=60
retry=3

REVO_HOST="reta-vortaro.de"
url=https://${REVO_HOST}/cgi-bin/admin/redaktantoj.pl

# legu sekretojn...
CGI_USER=${CGI_USER}||$(cat /run/secrets/voko-araneo.cgi_user)
CGI_PASSWORD=${CGI_PASSWORD}||$(cat /run/secrets/voko-araneo.cgi_password)

# legu aktualan liston de redaktantoj
echo "${redj} <- ${url}" 
curl -o ${redj} --fail --user ${CGI_USER}:${CGI_PASSWORD} --max-time ${timeout} --retry ${retry} ${url}