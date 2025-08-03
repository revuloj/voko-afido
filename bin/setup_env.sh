#!/bin/bash

# set -x

if [[ -z "$REVO_HOST" ]]; then
    export REVO_HOST="reta-vortaro.de"
    export ADM_URL="/cgi-bin/admin"
fi

if [[ -z "$ADM_USER" ]]; then
    if [[ $REVO_HOST = "reta-vortaro.de" || $REVO_HOST = "araneo" ]]; then
        export ADM_USER=$(cat /run/secrets/voko-araneo.cgi_user)
    else
        # cetonio
        export ADM_USER=submeto
    fi
fi

if [[ -z "$ADM_PASSWORD" ]]; then
    if [[ $REVO_HOST = "reta-vortaro.de" || $REVO_HOST = "araneo" ]]; then
        export ADM_PASSWORD=$(cat /run/secrets/voko-araneo.cgi_password)
    else
        # cetonio
        export ADM_PASSWORD=$(cat /run/secrets/voko-afido.adm_passwd)
    fi
fi