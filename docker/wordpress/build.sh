#!/usr/bin/env bash

export NS=${NS-dev}
export CONTEXT=${CONTEXT-google}
VERSION=$(grep FROM Dockerfile | sed "s/.*://")
echo "Publishing version $VERSION"

cd $(dirname $0)
docker build -t odoko/wordpress:$VERSION .

if [[ " $* " =~ .*\ push\ .* ]]; then
  docker push odoko/wordpress:$VERSION
fi
