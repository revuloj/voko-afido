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

if [ -z "$REVO_TOKEN" ]; then
  echo "Vi devas difini la medio-variablon REVO_TOKEN, kiun ni bezonas por saluti al Github."
  exit 1
fi

# ekstraktu la unuan dosieron el ĉiuj gistoj...
echo "## aktualigi ${api}/gists... $@"

for file in ${rezultoj}/*
do
  gist=$(basename ${file})
  rez=$(cat "$file"); rez=${rez//\"/\\\"}; rez=${rez//$'\n'/\\n}

  IFS= read -r -d '' data <<EOJ
  {
    "files": {
        "rezulto.log": {
          "content": "${rez}"
        }
    }
  }
EOJ
  echo "DATA:"
  echo "${data}"

  status=$(echo ${data} | curl -H "Authorization: token ${REVO_TOKEN}" -d '@-' -i -X PATCH ${api}/gists/${gist} | \
    grep "^Status:")
  echo "$gist: $status"

  ##echo ${data} | curl -H "Authorization: token ${REVO_TOKEN}" -d '@-' -i -X PATCH ${api}/gists/${gist}
done
    

