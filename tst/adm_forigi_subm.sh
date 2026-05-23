#!/bin/bash

stack=araneujotesto
cgi=adm_forigi_subm.pl
forigu_url=http://127.0.0.1:8088/cgi-bin/admin/${cgi}
cgi_adm=/usr/local/apache2/cgi-bin/admin

araneo_id=$(docker ps --filter name=${stack}_araneo -q) 

docker cp tst/${cgi} ${araneo_id}:${cgi_adm}/
docker exec ${araneo_id} chmod 755 ${cgi_adm}/${cgi}

adm_user=araneo
adm_pwd=$(docker exec ${araneo_id} cat /run/secrets/voko-araneo.cgi_password)

curl -s -w "stato: %{http_code}\n" --user ${adm_user}:${adm_pwd} ${forigu_url}