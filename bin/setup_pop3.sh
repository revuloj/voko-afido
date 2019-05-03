#!/bin/bash

# ni evitas sudo / root metante
# la agordon en dosierujojn de la nuna uzanto
fetchmailrc=.fetchmailrc
certs=${HOME}/etc/certs

# La variabloj ${POP3_SERVER} ${POP3_USER} ${POP3_PASSWORD}
# devos veni de ekstere, ekz. docker-compose.yml

# se .fetchmailrc ankoraŭ mankas, kreu ĝin uzante variablojn el la ĉirkaŭajo
#
if [ ! -e ${fetchmailrc} ]; then
    POP3_SERVER=$(cat /run/secrets/voko-afido.pop3_server)
    POP3_USER=$(cat /run/secrets/voko-afido.pop3_user)
    POP3_PASSWORD=$(cat /run/secrets/voko-afido.pop3_password)
    
    mkdir -p ${certs}
    openssl s_client -connect "${POP3_SERVER}":465 -showcerts > "${certs}/${POP3_SERVER}.cert.pem"
    c_rehash ${certs}
    echo "poll ${POP3_SERVER} proto pop3 user \"${POP3_USER}\" password ${POP3_PASSWORD} sslproto TLS1 sslcertpath ${certs}" > ${fetchmailrc}
    chmod u-w ${fetchmailrc}
fi
