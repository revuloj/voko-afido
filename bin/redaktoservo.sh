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
CGI_USER=$(cat /run/secrets/voko-araneo.cgi_user)
CGI_PASSWORD=$(cat /run/secrets/voko-araneo.cgi_password)

# legu aktualan liston de redaktantoj
echo "${redj} <- ${url}" | tee ${log}
curl -o ${redj} --user ${CGI_USER}:${CGI_PASSWORD} ${url} | tee -a ${log}

### prenu retpoŝtojn...

fetchmail | tee -a ${log}

#### nun traktu redaktojn kaj fine forsendu raportojn

if [[ -s /var/spool/mail/revo ]]; then
    echo -e "${proc}\nTIME:" $(date)"\n" | tee -a ${log}
    ${proc} 2>&1 | tee -a ${log}
    sendmail -q | tee -a ${log}
fi


