#!/bin/bash

etc=${HOME}/etc
url=http://${REVO_HOST}/cgi-bin/admin/redaktantoj-json.pl

mkdir -p ${etc}

echo "${etc}/redaktantoj.json <- ${url}"
curl -o ${etc}/redaktantoj.json --user ${CGI_USER}:${CGI_PASSWORD} ${url}
