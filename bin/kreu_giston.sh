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
  return 1
fi

if [ -z "$REVO_TOKEN" ]; then
  echo "Vi devas difini la medio-variablon REVO_TOKEN, kiun ni bezonas por saluti al Github."
  return 1
fi

if [ -z "$RETADRESO" ]; then
  echo "Vi devas difini la medio-variablon RETADRESO, kiun ni bezonas por identigi la redaktanton."
  return 1
fi


file=$1
fname=$(basename $file)
xml=$(cat $file)
xml=${xml//\"/\\\"}
xml=${xml//$'\n'/\\n}
#echo "\"${xml}\""

sigelilo="asefawq3485wef2354awemfpwej"
# elkalkulu HMAC
HMAC=$((echo ${RETADRESO} && cat $file) | openssl dgst -sha256 -hmac "${sigelilo}"); HMAC=${HMAC#*= }

info="{\n\"red_id\":\"1\",\n\"red_nomo\":\"Testa Redaktanto\",\n\"sigelo\":\"${HMAC}\",\n\"celo\":\"revo-fonto-testo/revo\"\n}"
info=${info//\"/\\\"}

echo "$info"

IFS= read -r -d '' json <<EOJ
{
  "description": "testo",
  "files": {
    "${fname}": {
      "content": "${xml}"
    },
    "info.json": {
      "content": "${info}"
    }
  }
}
EOJ


#echo $json

curl -H "Authorization: token ${REVO_TOKEN}" -X POST ${api}/gists -d "${json}"



