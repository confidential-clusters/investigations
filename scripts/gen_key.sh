#!/bin/bash

DIR=trustee/keys
mkdir -p "$DIR"

openssl genpkey -algorithm ed25519 > $DIR/private.key
openssl pkey -in private.key -pubout -out $DIR/public.pub
