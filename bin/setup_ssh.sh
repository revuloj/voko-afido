#!/bin/bash

cat /run/secrets/voko-afido.ssh_key.pub >> /home/afido/.ssh/authorized_keys 
chown -R afido.users /home/afido/.ssh 
chmod 0700 /home/afido/.ssh
chmod 0600 /home/afido/.ssh/*

