#!/bin/bash

# Github API, Auth
# https://developer.github.com/apps/building-github-apps/authenticating-with-github-apps/
# https://developer.github.com/changes/2020-02-14-deprecating-password-auth/

# JQ en bash-skriptoj
# https://stackoverflow.com/questions/43192556/using-jq-with-bash-to-run-command-for-each-object-in-array

# anstataŭigo de \n kaj \"
# https://stackoverflow.com/questions/1251999/how-can-i-replace-a-newline-n-using-sed/1252191#1252191
# ${message//[0-9]/X}
# y=${x//\"/\\\"}
# y=${x//$'\n'/\\n}


api=https://api.github.com
owner=reta-vortaro

if [ $# -eq 0 ]; then
  echo "Vi devas doni XML-dosieron kiel argumento."
  exit 1
fi

if [ -z "$REVO_TOKEN" ]; then
  echo "Vi devas difini la medio-variablon REVO_TOKEN, kiun ni bezonas por saluti al Github."
  exit 1
fi

if [ -z "$SIGELILO" ]; then
  echo "Vi devas difini la medio-variablon SIGELILO, kiun ni bezonas por sigeli la dosieron."
  exit 1
fi

if [ -z "$RETADRESO" ]; then
  echo "Vi devas difini la medio-variablon RETADRESO, kiun ni bezonas por identigi la redaktanton."
  exit 1
fi

file=$1
fname=$(basename $file)
xml=$(cat $file)
xml=${xml//\"/\\\"}
xml=${xml//$'\n'/\\n}
#echo "\"${xml}\""

# elkalkulu HMAC
HMAC=$((echo ${RETADRESO} && cat $file) | openssl dgst -sha256 -hmac "${SIGELILO}"); HMAC=${HMAC#*= }

IFS= read -r -d '' info <<EOI
{
  "red_id": "1",
  "red_nomo": "Testa Redaktanto",
  "sigelo": "${HMAC}",
  "celo": "revo-fonto-testo/revo"
}
EOI

info=$(echo $info | jq '@json')

#echo "$info"

IFS= read -r -d '' json <<EOJ
{
  "description": "redakto:testo",
  "files": {
    "${fname}": {
      "content": "${xml}"
    },
    "info.json": {
      "content": ${info}
    }
  }
}
EOJ


echo ${json} | jq '.'

echo ${json} | curl -H "Content-Type: application/json" -H "Authorization: token ${REVO_TOKEN}" -d '@-' -i -X POST ${api}/gists 



