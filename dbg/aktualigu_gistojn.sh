#!/bin/bash

# Github API, Auth
# https://developer.github.com/apps/building-github-apps/authenticating-with-github-apps/
# https://developer.github.com/changes/2020-02-14-deprecating-password-auth/

# JQ en bash-skriptoj
# https://stackoverflow.com/questions/43192556/using-jq-with-bash-to-run-command-for-each-object-in-array

api=https://api.github.com
owner=reta-vortaro

# dosierujoj
rezultoj=dict/rez
#gists=dict/gists
#xml=dict/xml
#json=dict/json

#if [ $# -eq 0 ]; then
#  echo "Vi devas doni la liston de forigendaj gistoj kiel argumentoj."
#  return 1
#fi

echo "####### Aktualigo de traktitaj redaktoj alpendigante rezultojn (konfirmo.json aŭ eraro.json) ########"

if [ -z "$REVO_TOKEN" ]; then
  echo "Vi devas difini la medio-variablon REVO_TOKEN, kiun ni bezonas por saluti al Github."
  exit 1
fi

# ekstraktu la unuan dosieron el ĉiuj gistoj...
echo "## aktualigi ${api}/gists... "

IFS= read -r -d '' eraro <<EOE
{
  "rezulto":"eraro",
  "shangho":"brita urbo Dovero/Dovro en aparata artikolo",
  "senddato":"2020-05-29T16:21:34Z",
  "artikolo":"\$Id: dovr.xml,v 1.1 2020/05/28 21:34:18 revo Exp \$",
  "mesagho":"La de vi sendita artikolo||ne baziĝas sur la aktuala arkiva versio||(\$Id: dovr.xml,v 1.2 2020/05/29 16:45:17 revo Exp \$)||Bonvolu preni aktualan version el la TTT-ejo. (http://www.reta-vortaro.de/cgi-bin/vokomail.pl?art=dovr)",
  "dosiero":"/home/afido/dict/xml/5d87c99cd8c4f33b7fc998d6aa8bcb84.xml"
}
EOE
echo ${eraro} | jq '.'  
eraro=$(echo $eraro | jq '@json')

gist="5d87c99cd8c4f33b7fc998d6aa8bcb84"
#  esc=${esc//\\/\\\\}; 
#  esc=${esc//\"/\\\"}; 
#  esc=${esc//$'\n'/\\n}

  # noto: ne uzu citilojn ĉirkaŭ $esc, ĉar tiujn jam aldonas jq '@json'!
IFS= read -r -d '' data <<EOJ
  {
    "files": {
        "eraro.json": {
          "content": ${eraro}
        }
    }
  }
EOJ

echo "DATA:"
echo ${data} | jq '.'  

#echo ${data} | cut -c31-61

status=$(echo ${data} | curl -H "Content-Type: application/json" -H "Authorization: token ${REVO_TOKEN}" -d '@-' \
    --progress-bar -i -X PATCH ${api}/gists/${gist})
echo "$gist: $status"

##echo ${data} | curl -H "Authorization: token ${REVO_TOKEN}" -d '@-' -i -X PATCH ${api}/gists/${gist}
    
echo "####### Fino de aktualigado ########"
echo
