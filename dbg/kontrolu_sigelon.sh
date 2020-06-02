#!/bin/bash

gist=$1;

if [[ -z "$SIGELILO" ]]; then
  echo "Vi devas antaŭdifini variablon SIGELILO per kiu ni kontrolas la sigelon."
  exit 1
fi 

if [[ -z "$RETADRESO" ]]; then
  echo "Vi devas antaŭdifini variablon RETADRESO per kiu ni kontrolas la sigelon."
  exit 1
fi 

if [[ -z "$gist" ]]; then
  echo "Vi devas doni numeron de gisto de kiu ni kontrolas la sigelon."
  exit 1
fi 

HMAC_red_xml () {
  local red_adr=$1
  local xml=$2
  local hmac=$((echo ${red_adr} && cat ${xml}) | openssl dgst -sha256 -hmac "${SIGELILO}");
  echo ${hmac#*= }
}

SHA1_red7 () {
  local red_adr=$1
  local sha=$(echo -n ${red_adr} | openssl dgst -sha1);
  sha=${sha#*= }
  #local sha=$(perl -MDigest::SHA=sha1_hex -e "print sha1_hex(\"${red_adr}\")")
  echo ${sha:0:7}
}

red7=$(SHA1_red7 $RETADRESO)
echo "SHA-red7: $red7"

hmac=$(HMAC_red_xml $RETADRESO "dict/xml/$gist.xml")
echo "|$RETADRESO|$SIGELILO|"
echo "HMAC: $hmac"
