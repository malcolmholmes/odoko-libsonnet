#!/bin/bash

ttlify() {
  local i
  for i in "$@"; do
    [[ "${i}" =~ ^([0-9]+)([a-z]*)$ ]] || continue
    local num="${BASH_REMATCH[1]}"
    local unit="${BASH_REMATCH[2]}"
    case "${unit}" in
                     weeks|week|wee|we|w) unit=''; num=$[num*60*60*24*7];;
                           days|day|da|d) unit=''; num=$[num*60*60*24];;
                     hours|hour|hou|ho|h) unit=''; num=$[num*60*60];;
      minutes|minute|minut|minu|min|mi|m) unit=''; num=$[num*60];;
      seconds|second|secon|seco|sec|se|s) unit=''; num=$[num];;
    esac
    echo "${num}${unit}"
  done
}

connect() {
  AUTH=/var/run/secrets/dns-auth/key
  SERVICE_ACCOUNT=$(jq -r .client_email $AUTH)
  GOOGLE_PROJECT=$(jq -r .project_id $AUTH)
  echo $AUTH / $SERVICE_ACCOUNT / $GOOGLE_PROJECT
  gcloud auth activate-service-account $SERVICE_ACCOUNT --key-file=$AUTH
  gcloud config set project $GOOGLE_PROJECT
}

dns_start() {
  gcloud dns record-sets transaction start    -z "${ZONENAME}"
}

dns_info() {
  gcloud dns record-sets transaction describe -z "${ZONENAME}"
}

dns_abort() {
  gcloud dns record-sets transaction abort    -z "${ZONENAME}"
}

dns_commit() {
  gcloud dns record-sets transaction execute  -z "${ZONENAME}"
}

dns_add() {
  if [[ -n "$1" && "$1" != '@' ]]; then
    local -r name="$1.${ZONE}."
  else
    local -r name="${ZONE}."
  fi
  local -r ttl="$(ttlify "$2")"
  local -r type="$3"
  shift 3
  gcloud dns record-sets transaction add -z "${ZONENAME}" --name "${name}" --ttl "${ttl}" --type "${type}" "$@"
}

dns_del() {
  if [[ -n "$1" && "$1" != '@' ]]; then
    local -r name="$1.${ZONE}."
  else
    local -r name="${ZONE}."
  fi
  local -r ttl="$(ttlify "$2")"
  local -r type="$3"
  shift 3
  gcloud dns record-sets transaction remove -z "${ZONENAME}" --name "${name}" --ttl "${ttl}" --type "${type}" "$@"
}

lookup_dns_ip() {
  host "$1" | grep -v "handled" | sed "s/.* //" 
}

my_ip() {
  curl -s ipecho.net/plain
}

doit() {
  echo "$(date) Processing $ZONE..."
  CURRENT=$(lookup_dns_ip $ZONE)
  NEW=$(my_ip)
  if [ "$CURRENT" = "$NEW" ]; then
    echo "$(date) $ZONE: No change required: $CURRENT" | tee -a /var/log/mouthpiece-dns.log
  else
    dns_start
    dns_del '@' 1min A $CURRENT
    dns_add '@' 1min A $NEW
    dns_commit
    echo "$(date) $ZONE: Updated from $CURRENT to $NEW" | tee -a /var/log/mouthpiece-dns.log
  fi
  echo
}

connect
for ZONE in $DOMAINS; do
  doit
done
