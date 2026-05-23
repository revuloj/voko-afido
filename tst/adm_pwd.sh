#!/bin/bash

stack=araneujotesto
araneo_id=$(docker ps --filter name=${stack}_araneo -q) 

#adm_user=araneo
adm_pwd=$(docker exec ${araneo_id} cat /run/secrets/voko-araneo.cgi_password)

echo -n "$adm_pwd"