#!/bin/bash

# kreas tagan resumon de prokoloj de la redaktoservo (retpoŝta)
# la ideo estas post elfiltro de interesaj linioj ankaŭ sendi ĝin al administranto per
# per ŝaltilo -a ni rigardas la protokolojn de la antaŭa tago
#
# $ taga-resumo.sh  mail -s "redakto-servo - taga resumo" mia@poshtservo.org

log_prefix="${HOME}/log/redsrv-"

if [[ "$1" == "-a" ]]; then
    date=$(date +"%Y%m%d" -d "1 day ago")
else
    date=$(date +"%Y%m%d")
fi

grep -2 -E "(fatal|fail|artikolo:)" ${log_prefix}${date}*