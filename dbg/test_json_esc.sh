#!/bin/bash

set -x

# JQ en bash-skriptoj
# https://stackoverflow.com/questions/43192556/using-jq-with-bash-to-run-command-for-each-object-in-array

# anstataŭigo de \n kaj \"
# https://stackoverflow.com/questions/1251999/how-can-i-replace-a-newline-n-using-sed/1252191#1252191
# ${message//[0-9]/X}
# y=${x//\"/\\\"}
# y=${x//$'\n'/\\n}


#if [ $# -eq 0 ]; then
#  echo "Vi devas doni XML-dosieron kiel argumento."
#  exit 1
#fi
#
#file=$1
#fname=$(basename $file)
#xml=$(cat $file)
#xml=${xml//\"/\\\"}
#xml=${xml//$'\n'/\\n}
##echo "\"${xml}\""

#IFS= read -r -d '' info << EOI
#{
# "rezulto": "konfirmo",
# "artikolo": "\$Id: karaktr.xml,v\$",
# "senddato": "2020-05-27T14:50:18Z",
# "mesagho": "[fa44d97903] Wolfram Diestel: nova artikolo\n1 dosiero, 63 enmetoj(+)\ncreate mode 100644 revo/karaktr.xml\n"
#}
#EOI

IFS= read -r -d '' info <<EOI
{
 "rezulto": "konfirmo",
 "artikolo": "\$Id: karaktr.xml,v\$",
 "senddato": "2020-05-27T14:50:18Z",
 "mesagho": "[fa44d97903] Wolfram Diestel: nova artikolo\n1 dosiero, 63 enmetoj(+)\ncreate mode 100644 revo/karaktr.xml\n"
}
EOI

#"eraro.json": {
#     "content": ""
#        }

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

#echo "$info"
fname="xml"
xml="x"
echo ${info} | jq '.'
info=$(echo $info | jq '@json')
eraro=$(echo $eraro | jq '@json')

#IFS= read -r -d '' json <<EOJ
#{
#  "description": "redakto:testo",
#  "files": {
#    "${fname}": {
#      "content": ${xml}
#    },
#    "info.json": {
#      "content": ${info}
#    }
#  }
#}
#EOJ

IFS= read -r -d '' json <<EOJ
{
  "description": "redakto:testo",
  "files": {
    "${fname}": {
      "content": "${xml}"
    },
    "eraro.json": {
      "content": ${eraro}
    }
  }
}
EOJ

echo ${info} | jq '.'
echo ${json} | jq '.'

#echo ${json} | cut -c109-119




