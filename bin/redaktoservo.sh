#!/bin/bash

basedir=${HOME}
etc=${basedir}/etc
redj=${etc}/voko.redaktantoj
proc=${HOME}/voko-afido/bin/processmail.pl

datetime=$(date +%Y%m%d_%H%M%S)
log=${HOME}/log/redsrv-${datetime}.log

REVO_HOST="reta-vortaro.de"
url=https://${REVO_HOST}/cgi-bin/admin/redaktantoj.pl

# legu sekretojn...
if [[ -z "$CGI_USER" ]]; then
  CGI_USER=$(cat /run/secrets/voko-araneo.cgi_user)
fi
if [[ -z "$CGI_PASSWORD" ]]; then
  CGI_PASSWORD=$(cat /run/secrets/voko-araneo.cgi_password)
fi

# legu aktualan liston de redaktantoj
echo "${redj} <- ${url}" | tee ${log}
curl -o ${redj} --user ${CGI_USER}:${CGI_PASSWORD} ${url} 2>&1 | tee -a ${log}

### prenu retpoŝtojn...

fetchmail 2>&1 | tee -a ${log}

#### nun traktu redaktojn kaj fine forsendu raportojn

if [[ -s /var/spool/mail/revo ]]; then
    echo -e "${proc}\nTIME:" $(date)"\n" 2>&1 | tee -a ${log}
    ${proc} 2>&1 | tee -a ${log}
    sendmail -q 2>&1 | tee -a ${log}
fi


