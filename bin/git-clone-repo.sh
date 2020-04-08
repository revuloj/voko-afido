#!/bin/bash

basedir=. #/home/afido
dict=${basedir}/dict
etc=${basedir}/etc

if [[ -z $GIT_REPO_REVO ]]; then
    echo "La medio-variablo GIT_REPO_REVO ne estas difinita."
    echo "Ne eblas preni Git-arĥivon. Bv. difini la variablon ĉe lanĉo de procesumo."
    exit 1
fi

repo_url=$(cat ${etc}/git_repos.json | jq -r --arg REPO "$GIT_REPO_REVO" '.[$REPO]')

echo "Elŝutante ${repo_url} al revo-fonto..."
git clone ${repo_url} ${dict}/revo-fonto

if [ ! "$(git config --global user.email)" ]; then
  echo "Metante Revo-uzanton por Git..."

  git config --file ${dict}/revo-fonto/.git/config user.email "RetaVortaro@steloj.de"
  git config --file ${dict}/revo-fonto/.git/config user.name "reta-vortaro"
fi
