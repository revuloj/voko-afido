#!/bin/bash

basedir="${REVO_DIR:-/home/afido}"
etc=${basedir}/etc
redj=${etc}/redaktantoj.json
timeout=60
retry=1
delay=300
ipv="--ipv4"

source setup_env.sh

# nun en setup_env.sh
#if [[ -z "$REVO_HOST" ]]; then
#    export REVO_HOST="reta-vortaro.de"
#fi
#
#if [[ -z "$CGI_USER" ]]; then
#    export CGI_USER=$(cat /run/secrets/voko-araneo.cgi_user)
#fi
#
#if [[ -z "$CGI_PASSWORD" ]]; then
#    export CGI_PASSWORD=$(cat /run/secrets/voko-araneo.cgi_password)
#fi
if [[ "$REVO_HOST" = "reta-vortaro.de" ]]; then
    url=https://${REVO_HOST}/cgi-bin/admin/redaktantoj-json.pl
else
    # ni prenas jam pretan JSON, ekz-e de svagaj steloj
    url=https://${REVO_HOST}/admin/redaktantoj.json
fi

mkdir -p ${etc}

echo "${etc}/redaktantoj.json <- ${url}"
curl -o ${etc}/redaktantoj.json --user ${CGI_USER}:${CGI_PASSWORD} ${ipv} --max-time ${timeout} --retry ${retry} --retry-delay ${delay} ${url}
