#!/bin/bash
set -x

basedir=. #/home/afido
dict=${basedir}/dict
etc=${basedir}/etc

if [[ -z $GIT_REPO_REVO ]]; then
    echo "La medio-variablo GIT_REPO_REVO ne estas difinita."
    echo "Ne eblas preni Git-arĥivon. Bv. difini la variablon ĉe lanĉo de procesumo."
    exit 1
fi

if [[ ! -z $GITHUB_TOKEN ]]; then
  git_credentials_prefix="https://x-access-token:${GITHUB_TOKEN}@github.com/"
# se ni volas subteni ankaŭ DEPLOY-TOKEN...
# elif [[ ! -z $GITHUB_DEPLOYKEY ]]  ...
#    git_credentials_prefix=https://github.com/" 
elif [[ -s "/run/secrets/voko-afido.github_key" ]]; then
  git_credentials_prefix=git@github.com:
else
  git_credentials_prefix=""
fi

# https://github.com/ad-m/github-push-action/blob/master/start.sh
# "https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${REPOSITORY}.git"
# aŭ https://www.innoq.com/de/blog/github-actions-automation/
# repo_uri="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
repo=$(cat ${etc}/git_repos.json | jq -r --arg REPO "$GIT_REPO_REVO" '.[$REPO]')
repo_url="${git_credentials_prefix}${repo}"

echo "Elŝutante ${repo} al revo-fonto..."
git clone ${repo_url} ${dict}/revo-fonto

if [ ! "$(git config --global user.email)" ]; then
  echo "Metante Revo-uzanton por Git..."

  git config --file ${dict}/revo-fonto/.git/config user.email "RetaVortaro@steloj.de"
  git config --file ${dict}/revo-fonto/.git/config user.name "reta-vortaro"
fi
