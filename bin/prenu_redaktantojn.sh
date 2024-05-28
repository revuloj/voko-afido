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

if [[ "$REVO_HOST" == svagaj* ]]; then
    # ni prenas jam pretan JSON, ekz-e de svagaj steloj
    url=https://${REVO_HOST}/admin/redaktantoj.json
else
    url=https://${REVO_HOST}/cgi-bin/admin/redaktantoj-json.pl
fi

mkdir -p ${etc}

echo "${etc}/redaktantoj.json <- ${url}"
curl -o ${etc}/redaktantoj.json --user ${CGI_USER}:${CGI_PASSWORD} ${ipv} --max-time ${timeout} --retry ${retry} --retry-delay ${delay} ${url}

# kontrolu ĉu ni ricevis JSON kaj ne eble HTML-eraron
first=$(head -c 1 ${etc}/redaktantoj.json)
if [[ "${first}" != "[" ]]; then
  echo "Ni atendis JSON-liston. Ŝajne redaktantoj ne ŝargiĝis ĝuste!"
  exit 1
fi

