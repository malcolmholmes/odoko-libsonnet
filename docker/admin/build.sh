#!/usr/bin/env bash

set -e

cd $(dirname $0)
docker build -t odoko/admin:latest .

if [[ " $* " =~ .*\ push\ .* ]]; then
  docker push odoko/admin:latest
fi

if [[ " $* " =~ .*\ deploy\ .* ]]; then
  echo deploy
  ## something kubectl here

fi
