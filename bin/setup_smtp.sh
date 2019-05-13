#!/bin/bash
set -x # trace
# set -e # exit on erros in pipe

ssmtpconf=/etc/ssmtp/ssmtp.conf

#if [ ! -e ${ssmtpconf} ]; then
SMTP_SERVER=$(cat /run/secrets/voko-afido.smtp_server)
SMTP_USER=$(cat /run/secrets/voko-afido.smtp_user)
SMTP_PASSWORD=$(cat /run/secrets/voko-afido.smtp_password)
# 25 neĉifrita, ĉifritaj pordoj 465 aŭ 587, sed ni ja uzos lokan servon voko-tomocero
SMTP_PORT=25

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