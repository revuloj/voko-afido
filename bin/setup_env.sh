#!/bin/bash

if [[ -z "$REVO_HOST" ]]; then
    export REVO_HOST="reta-vortaro.de"
fi

if [[ -z "$CGI_USER" ]]; then
    export CGI_USER=$(cat /run/secrets/voko-araneo.cgi_user)
fi

if [[ -z "$CGI_PASSWORD" ]]; then
    export CGI_PASSWORD=$(cat /run/secrets/voko-araneo.cgi_password)
fi