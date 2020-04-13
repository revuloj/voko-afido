#!/bin/bash

# Github API, Auth
# https://developer.github.com/apps/building-github-apps/authenticating-with-github-apps/
# https://developer.github.com/changes/2020-02-14-deprecating-password-auth/

# JQ en bash-skriptoj
# https://stackoverflow.com/questions/43192556/using-jq-with-bash-to-run-command-for-each-object-in-array

# HMAC, JWT w. OpenSSL / bash
# https://stackoverflow.com/questions/7285059/hmac-sha1-in-bash
# https://willhaley.com/blog/generate-jwt-with-bash/

api=https://api.github.com
owner=reta-vortaro

if [ -z "$REVO_TOKEN" ]; then
  echo "Vi devas difini la medio-variablon REVO_TOKEN, kiun ni bezonas por saluti al Github."
  exit 1
fi

datediff() {
    dt=$(date -d "$1" +%s)
    today=$(date +%s)
    echo $(( (today - dt) / 86400 ))
}

# ekstraktu id, updated_at kaj dosiernomon 'rezulto.log' el ĉiuj gistoj
echo "## preni ${api}/gists..."
curl -H "Authorization: token ${REVO_TOKEN}" -X GET --progress-bar ${api}/gists | \
    jq -c '.[] | { id, updated_at, files }' | \
while IFS=$"\n" read -r line; do
    # echo "DEBUG (line): $line"
    id=$(echo $line | jq -r '.id')
    dt=$(echo $line | jq -r '.updated_at')
    lg=$(echo $line | jq -r '.files["rezulto.log"]')
    # ignoru jam traktitajn...
    if [[ "$lg" != "null" ]]; then
      age = $( datediff "$dt" )
      echo "aĝo: $age tagoj"
      if [[ $age > 14 ]]; then
        echo "# forigas ${gists}/${id}..."
        status=$(curl -H "Authorization: token ${REVO_TOKEN}" -i -X DELETE ${api}/gists/${gist} | \
          grep "^Status:")
        echo "$gist: $status"
      fi
    fi
done

