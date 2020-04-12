#!/bin/bash
# set -x # trace
# set -e # exit on erros in pipe

ssmtpconf=/etc/ssmtp/ssmtp.conf
mailsenderconf=/etc/mailsender.conf

#if [ ! -e ${ssmtpconf} ]; then
if [[ -z "$SMTP_SERVER" ]]; then
    SMTP_SERVER=$(cat /run/secrets/voko-afido.smtp_server)
fi

if [[ -z "$SMTP_USER" ]]; then
    SMTP_USER=$(cat /run/secrets/voko-afido.smtp_user)
fi

if [[ -z "$SMTP_PASSWORD" ]]; then
    SMTP_PASSWORD=$(cat /run/secrets/voko-afido.smtp_password)
fi

# 25 neĉifrita, ĉifritaj pordoj 465 aŭ 587
SMTP_PORT=587

cat <<EOC > ${mailsenderconf}
{
    "server": "${SMTP_SERVER}",
    "user": "${SMTP_USER}",
    "password": "${SMTP_PASSWORD}",
    "port": "${SMTP_PORT}"
}
EOC

cat <<EOT > ${ssmtpconf}
# The user that gets all the mails (UID < 1000, usually the admin)
#root=username@gmail.com
mailhub=${SMTP_SERVER}:${SMTP_PORT}
# la sekvajn du prizorgos voko-tomocero
# The address where the mail appears to come from for user authentication.
#rewriteDomain=steloj.de
# The full hostname.  Must be correctly formed, fully qualified domain name or mailserver could reject connection.
#hostname=yourlocalhost.yourlocaldomain.tld
hostname=afido

# Use SSL/TLS before starting negotiation
UseTLS=No
UseSTARTTLS=No

# Username/Password
AuthUser=${SMTP_USER}
AuthPass=${SMTP_PASSWORD}
AuthMethod=LOGIN

# Email 'From header's can override the default domain?
FromLineOverride=yes
EOT

#fi