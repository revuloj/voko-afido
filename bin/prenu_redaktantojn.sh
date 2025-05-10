#!/bin/bash

basedir="${REVO_DIR:-/home/afido}"
etc=${basedir}/etc
redj=${etc}/redaktantoj.json
timeout=60
retry=1
delay=300
ipv="--ipv4"

source setup_env.sh

# REVO_HOST kaj CGI-variabloj estas difinitaj en setup_env.sh

url=https://${REVO_HOST}${ADM_URL}/redaktantoj-json.pl

mkdir -p ${etc}

echo "${etc}/redaktantoj.json <- ${url}"
curl -o ${etc}/redaktantoj.json --user ${ADM_USER}:${ADM_PASSWORD} ${ipv} --max-time ${timeout} --retry ${retry} --retry-delay ${delay} ${url}

# kontrolu ĉu ni ricevis JSON kaj ne eble HTML-eraron
first=$(head -c 1 ${etc}/redaktantoj.json)
if [[ "${first}" != "[" ]]; then
  echo "Ni atendis JSON-liston. Ŝajne redaktantoj ne ŝargiĝis ĝuste!"
  exit 1
fi

