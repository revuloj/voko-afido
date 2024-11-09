#!/bin/bash

# por loka uzo, t.e. ekster docker-procezujo
# Ni nur traktas retpoŝtajn redaktojn per tiu ĉi skripto.
# Ni supozas ke en la operaciumo estas instalita
# fetchmail por ricevi retpoŝtajn redaktojn kaj
# poŝtservo al kiu ni sendas konfirmojn kaj fine
# forsendas per sendmail -q

basedir=${HOME}
etc=${basedir}/etc
redj=${etc}/voko.redaktantoj
proc=${HOME}/voko-afido/bin/processmail.pl
timeout=60
retry=3

datetime=$(date +%Y%m%d_%H%M%S)
log=${HOME}/log/redsrv-${datetime}.log

REVO_HOST="reta-vortaro.de"
url=https://${REVO_HOST}/cgi-bin/admin/redaktantoj.pl

# legu sekretojn...
CGI_USER=${CGI_USER}||$(cat /run/secrets/voko-araneo.cgi_user)
CGI_PASSWORD=${CGI_PASSWORD}||$(cat /run/secrets/voko-araneo.cgi_password)

# legu aktualan liston de redaktantoj
echo "${redj} <- ${url}" | tee ${log}
curl -o ${redj} --fail --user ${CGI_USER}:${CGI_PASSWORD} --max-time ${timeout} --retry ${retry} ${url} 2>&1 | tee -a ${log}

### prenu retpoŝtojn...

fetchmail 2>&1 | tee -a ${log}

#### nun traktu redaktojn kaj fine forsendu raportojn

if [[ -s /var/spool/mail/revo ]]; then
    echo -e "${proc}\nTIME:" $(date)"\n" 2>&1 | tee -a ${log}
    ${proc} 2>&1 | tee -a ${log}
    sendmail -q 2>&1 | tee -a ${log}
fi


