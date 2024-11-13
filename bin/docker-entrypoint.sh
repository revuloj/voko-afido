#!/bin/bash
#set -e
#set -x

# laŭbezone kreu agordon por fetchmail kaj ssmtp - tio okazos nur se la dosieroj
# ankoraŭ mankas. Por ŝanĝi ilin necesas rekrei la procesumon voko-afido kun ŝanĝitaj sekretoj
# aŭ forigi fetchmailrc kaj ssmtp.conf

source setup_env.sh
setup_ssh.sh
# ni ne plu uzas ssmtp...
setup_smtp.sh
setup_var.sh
setup_dict.sh

echo "AFIDO_PORT=${AFIDO_PORT}"
echo "lanĉo: $@"

exec "$@"