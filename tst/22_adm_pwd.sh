#!/bin/bash

stack=araneujotesto
araneo_id=$(docker ps --filter name=${stack}_araneo -q) 

cgi_user=araneo
cgi_pwd=$(docker exec ${araneo_id} cat /run/secrets/voko-araneo.cgi_password)

echo -n "$cgi_pwd"