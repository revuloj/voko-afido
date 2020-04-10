#!/bin/bash

# Github API, Auth
# https://developer.github.com/apps/building-github-apps/authenticating-with-github-apps/
# https://developer.github.com/changes/2020-02-14-deprecating-password-auth/

# JQ en bash-skriptoj
# https://stackoverflow.com/questions/43192556/using-jq-with-bash-to-run-command-for-each-object-in-array


api=https://api.github.com
owner=reta-vortaro

# dosierujoj
pretaj=dict/pretaj
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
echo "## forigi ${api}/gists... $@"

for file in ${pretaj}/*
do
  gist=$(basename ${file})
  status=$(curl -H "Authorization: token ${REVO_TOKEN}" -I -X DELETE ${api}/gists/${gist} | \
    grep "^Status:")
  echo "$gist: $status"
done
    
#<script src="https://gist.github.com/reta-vortaro/5a57af79efb47e5139cd56a21d676eb9.js"></script>    

