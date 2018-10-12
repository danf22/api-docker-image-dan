#!/usr/bin/env bash

JWT_PASSPHRASE=8bf8918cca32bd3af56d3bf5bb0d98d1

openssl genrsa -out /srv/api/config/jwt/private.pem -passout pass:$JWT_PASSPHRASE -aes256 4096;
openssl rsa -pubout -in /srv/api/config/jwt/private.pem -out /srv/api/config/jwt/public.pem -passin pass:$JWT_PASSPHRASE;

