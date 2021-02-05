#!/bin/bash

basedir=/home/afido
etc=${basedir}/etc
redj=${etc}/redaktantoj.json 

if [[ -z "$REVO_HOST" ]]; then
    REVO_HOST="reta-vortaro.de"
fi

if [[ -z "$CGI_USER" ]]; then
    CGI_USER=$(cat /run/secrets/voko-araneo.cgi_user)
fi

if [[ -z "$CGI_PASSWORD" ]]; then
    CGI_PASSWORD=$(cat /run/secrets/voko-araneo.cgi_password)
fi

url=https://${REVO_HOST}/cgi-bin/admin/redaktantoj-json.pl

mkdir -p ${etc}

echo "${etc}/redaktantoj.json <- ${url}"
curl -o ${etc}/redaktantoj.json --user ${CGI_USER}:${CGI_PASSWORD} ${url}
