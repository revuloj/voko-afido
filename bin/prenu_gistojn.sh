#!/bin/bash

# Github API, Auth
# https://developer.github.com/apps/building-github-apps/authenticating-with-github-apps/
# https://developer.github.com/changes/2020-02-14-deprecating-password-auth/

# JQ en bash-skriptoj
# https://stackoverflow.com/questions/43192556/using-jq-with-bash-to-run-command-for-each-object-in-array

# HMAC, JWT w. OpenSSL / bash
# https://stackoverflow.com/questions/7285059/hmac-sha1-in-bash
# https://willhaley.com/blog/generate-jwt-with-bash/

# httpd mock
# https://gist.github.com/willurd/5720255

api=https://api.github.com
owner=reta-vortaro
# dosierujoj
gists=dict/gists
xml=dict/xml
json=dict/json

unquote () {
  str=$1
  s1="${str%\'}"
  s2="${s1#\'}"
  echo "$s2"
}


mkdir -p ${gists}
mkdir -p ${xml}
mkdir -p ${json}
rm -f ${gists}/*
#curl -H "Authorization: token $tk" -X GET ${api}/gists | jq '.[] | { description, files: [ (.files[]|values) ][0]} '

#jq -c '.[] | { id, description, updated_at } + [ (.files[]|values) ][0]' | \

# ekstraktu la unuan dosieron el ĉiuj gistoj...
echo "## preni ${api}/gists..."
curl -H "Authorization: token ${REVO_TOKEN}" -X GET --progress-bar ${api}/gists | \
    jq -c '.[] | { id, description, updated_at, files }' | \
while IFS=$"\n" read -r line; do
    # echo "DEBUG (line): $line"
    id=$(echo $line | jq -r '.id')
    fn=$(echo $line | jq -r '.files[] | select(.type=="application/xml") | .filename')
    echo "# gisto \"${fn}\" -> ${gists}/${id}"
    echo $line | jq '.' > ${gists}/${id}
done

# elŝutu ĉiujn dosierojn laŭ la gisto-listo
for gist in ${gists}/*; do
  id=$(cat ${gist} | jq -r '.id')
  files=$(cat ${gist} | jq -r '.files | keys | @sh')

  for file in ${files}; do
    # echo "DEBUG (file): $(unquote ${file})"
    fjson=$(cat ${gist} | jq -r --arg f $(unquote ${file}) '.files[$f]')
    # echo "DEBUG (fjson): $fjson"
    sz=$(echo ${fjson} | jq -r '.size')
    tp=$(echo ${fjson} | jq -r '.type')

    if [[ "${tp}" == "application/xml" && "${sz}" -lt 1000000 ]]; then
      url=$(echo ${fjson} | jq -r '.raw_url')
      echo "## ${xml}/${id}.xml <- ${url}..."
      curl -o "${xml}/${id}.xml" -H "Authorization: token ${REVO_TOKEN}" --progress-bar "${url}"

    elif [[ "${tp}" == "application/json" && "${sz}" -lt 1000 ]]; then
      url=$(echo ${fjson} | jq -r '.raw_url')
      echo "## ${json}/${id}.json <- ${url}..."
      curl -o "${json}/${id}.json" -H "Authorization: token ${REVO_TOKEN}" --progress-bar "${url}"

    else
      echo "ERARO: dosiero ${id}/${file} havas malĝustan tipon aŭ estas tro granda:"
      cat ${gist} && rm ${gist}
    fi

  done

done