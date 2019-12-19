#!/bin/bash

docker build -t voko-afido .
docker tag voko-afido registry.local:5000/voko-afido
docker push registry.local:5000/voko-afido