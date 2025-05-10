#!/bin/bash

if [[ -z "$REVO_HOST" ]]; then
    export REVO_HOST="reta-vortaro.de"
    export ADM_URL="/cgi-bin/admin"
fi

if [[ -z "$ADM_USER" ]]; then
    export ADM_USER=$(cat /run/secrets/voko-araneo.cgi_user)
fi

if [[ -z "$ADM_PASSWORD" ]]; then
    export ADM_PASSWORD=$(cat /run/secrets/voko-araneo.cgi_password)
fi