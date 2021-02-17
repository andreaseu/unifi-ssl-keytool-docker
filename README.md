# unifi-ssl-keytool-docker
Docker container script for SSL certificate replacement via the Java Keytool Programm.

This is a shell script that replace the self-issued SSL certificate
of a Unifi controller for a signed certificate.
Without the installation of Java on the host system.

## UniFi Controller Docker Image
Tested with the following UniFi Controller Docker image on Raspberry Pi OS 64bit.
https://github.com/linuxserver/docker-unifi-controller

# Lets Certbot
Certbot is the official client from  [Let’s Encrypt](https://letsencrypt.org/)  to request SSL certificates. We will use the cloudflare-dns plugin to obtain certificates because it’s the easiest and the most flexible way (we don’t have to open any port for an HTTP challenge, we can request a certificate for any of our domain or subdomain and even a wildcard certificate). As usual, we will use a Docker container.
The official Certbot Docker image doesn’t support ARM architecture yet so we will build our image based on the official Dockerfiles.
Copied from https://github.com/gpailler

```
mkdir /opt/docker/certbot && cd /opt/docker/certbot
mkdir /opt/docker/certbot/etc
mkdir /opt/docker/certbot/lib
mkdir /opt/docker/certbot/logs

-- Create an cloudflare credentials file
tee cloudflare_credentials > /dev/null << EOF
dns_cloudflare_email = mail@example.com
dns_cloudflare_api_key = XXX000000YYYYY4444444444
EOF
chmod 600 cloudflare_credentials

-- Create an cloudflare credentials file
tee /opt/docker/certbot/certbot_script.sh > /dev/null << EOF
#!/usr/bin/env bash

# Setup an 'environment'
CFC=/opt/docker/certbot/cloudflare_credentials
ETC=/opt/docker/certbot/etc
LIB=/opt/docker/certbot/lib
LOG=/opt/docker/certbot/logs
MAIL="mail@example.com"

# I'll happily create the set of directories for you, if none exist yet:
if [ ! -d $ETC -a ! -d $LIB -a ! -d $LOG ]
then
  mkdir $ETC $LIB $LOG
  echo 'Directories created'
fi

# Check supplied arguments
if [ \( $# -gt 2 -o -z "$1" -o "$1" == "test" \) -o \( "$2" -a "$2" != "test" \) ]
then
  echo "Usage: $0 <command> [test] (e.g. certonly, renew)"
  exit 1
fi

# They looked good...read em
COMMAND=$1
if [ $2 ]
then
  TEST="--staging"
else
  SERVER="--server https://acme-v02.api.letsencrypt.org/directory"
fi

echo "Using etc: $ETC, /var/log: $LOG, /var/lib/letsencrypt: $LIB"

if [ $TEST ]; then echo '***TEST MODE***'; fi
echo "Running command: $COMMAND"

# Finally do something:
# The command runs *INTERACTIVELY* and has not (yet) been tested for renewals
sudo docker run -it --rm --name certbot \
   -v "$ETC:/etc/letsencrypt:rw" \
   -v "$LIB:/var/lib/letsencrypt:rw" \
   -v "$LOG:/var/log/letsencrypt:rw" \
   -v "$CFC:/etc/cloudflare_credentials:ro" \
   certbot/dns-cloudflare:arm64v8-latest \
   $COMMAND $TEST \
   --dns-cloudflare-credentials /etc/cloudflare_credentials \
   --dns-cloudflare-propagation-seconds 5 \
   --email $MAIL \
   --no-eff-email \
   --agree-to \
   $SERVER

echo 'Change a UniFi SSL Keys'
if [ -f /opt/docker/unifi/scripts/unifi_ssl.sh ]; then
    /opt/docker/unifi/scripts/unifi_ssl.sh
fi
EOF


-- Add an alias to run mtr like any other command
tee -a ~/.dotfiles/.my-zsh/aliases.zsh > /dev/null << "EOF"
alias certbot="/opt/docker/certbot/certbot_script.sh"
EOF

source ~/.zshrc

````

Now, we can call certbot by invoking the command
`certbot certonly test`

`certbot certonly`


`certbot renew` 

`sudo openssl x509 -noout -text -in /opt/docker/certbot/etc/live/domain.com/cert.pem`

## Cron Job

````
sudo crontab -e
4 4 */15 * * /opt/docker/certbot/certbot_script.sh renew >> /opt/docker/certbot/logs/renewal.log 2>&1
```

