#!/bin/bash

# Infinite loop to periodically renew certificates and reload web servers
# /usr/local/bin/certbot-renew
while true; do
  certbot renew --quiet --deploy-hook /usr/local/bin/reload-services
  sleep 12h
done
