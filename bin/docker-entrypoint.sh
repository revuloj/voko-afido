#!/bin/bash
#set -e
#set -x

# laŭbezone kreu agordon por fetchmail kaj smtp - tio okazos nur se la dosieroj
# ankoraŭ mankas. Por ŝanĝi ilin necesas rekrei la procesumon voko-afido kun ŝanĝitaj sekretoj
# aŭ forigi fetchmailrc kaj ssmtp.conf

source setup_env.sh
setup_ssh.sh
setup_smtp.sh
setup_var.sh
setup_dict.sh

exec "$@"