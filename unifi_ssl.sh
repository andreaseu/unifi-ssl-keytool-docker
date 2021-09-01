#!/usr/bin/env bash
# This is a shell script that replace the self-issued SSL certificate 
# of a Unifi controller for a signed certificate.
# Tested with the following UniFi Controller Docker image:
# https://github.com/linuxserver/docker-unifi-controller
# 
# Scripted by Andreas Hähnel - https://github.com/andreaseu

# Setup an 'environment'
DOMAIN=unifi.example.com #UniFi URL
UNIFIPATH=/opt/docker/unifi/config/data #Destination Path
CERTPATH=/opt/docker/certbot/etc/live #Source Path Certificates cert.pem, privkey.pem, chain.pem
TEMPPATH=/opt/docker/unifi/scripts/temp #Temp Path
USERID=1000 #UserID for Docker Container
GROUPID=1000 #GroupID for Docker Container
UNIFIDOCKER=unifi #Unifi Dockername

# I'll happily create the set of directories for you, if none exist yet:
if [ ! -d $TEMPPATH ]
then
  mkdir $TEMPPATH
  echo 'Directories created'
fi

echo 
if [ ! -f $CERTPATH/$DOMAIN/cert.pem ]; then
    echo 'No certificate cert.pem found!'
    exit
else
    echo 'Certificate cert.pem found!'
fi
if [ ! -f $CERTPATH/$DOMAIN/privkey.pem ]; then
    echo 'No private key privkey.pem found!'
    exit
else
    echo 'Private key privkey.pem found!'
fi
if [ ! -f $CERTPATH/$DOMAIN/chain.pem ]; then
    echo 'No certificate chain chain.pem found!'
    exit
else
    echo 'Certificate chain chain.pem found!'
fi

if [ ! -f $TEMPPATH/cloudkey.p12 ]; then
   echo 'No Backup cloudkey.p12 needed'
else
   echo 'Backup cloudkey.p12 to cloudkey.p12.backup'
   mv $TEMPPATH/cloudkey.p12 $TEMPPATH/cloudkey.p12.backup
fi
if [ ! -f $TEMPPATH/keystore ]; then
   echo 'No Backup keystore needed'
else
   echo 'Backup keystore to keystore.backup'
   mv $TEMPPATH/keystore $TEMPPATH/keystore.backup
fi

echo 'Create P12 File'
openssl pkcs12 -export -in $CERTPATH/$DOMAIN/cert.pem \
    -inkey $CERTPATH/$DOMAIN/privkey.pem \
    -out $TEMPPATH/cloudkey.p12 \
    -name unifi \
    -CAfile $CERTPATH/$DOMAIN/chain.pem \
    -caname root \
    -password pass:aircontrolenterprise

echo 'Run Java Docker Container and convert the P12 File to Java Keystore'
docker run --rm --name=keytool \
    -v $TEMPPATH:/temp/certs \
    openjdk:latest \
    bash -c 'cd /temp/certs && keytool -importkeystore -deststorepass aircontrolenterprise -destkeypass aircontrolenterprise -destkeystore /temp/certs/keystore -srckeystore /temp/certs/cloudkey.p12 -srcstoretype PKCS12 -srcstorepass aircontrolenterprise -alias unifi' \
    -e PUID=$USERID \
    -e PGID=$GROUPID

echo 'Copy Java Keystore from temp folder to the unifi folder'
if [ ! -f $UNIFIPATH/keystore ]; then
   echo 'No Backup keystore needed'
else
   echo 'Backup keystore to keystore.backup'
   mv $UNIFIPATH/keystore $UNIFIPATH/keystore.backup
fi

cp $TEMPPATH/keystore $UNIFIPATH/keystore

echo 'Restart Docker Container ' $UNIFIDOCKER
docker container restart $UNIFIDOCKER

# Manuel Set up as scheduled task
# sudo crontab -e
#4 4 */15 * * /opt/docker/unifi/scripts/unifi_ssl.sh renew >> /opt/docker/unifi/scripts/renewal.log 2>&1
