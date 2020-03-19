#!/usr/bin/env bash

export NS=${NS-dev}
export CONTEXT=${CONTEXT-google}

cd $(dirname $0)
docker build -t odoko/wordpress .

if [[ " $* " =~ .*\ push\ .* ]]; then
  docker push odoko/wordpress
fi

if [[ " $* " =~ .*\ deploy\ .* ]]; then
  echo deleting pod
  kubectl --context $CONTEXT delete pod -n $NS wordpress-0

fi
