#!/bin/bash

set -e

export CMD=${CMD?"required"}
export GOOGLE_PROJECT=$(jq -r .project_id /var/run/secrets/dns-auth/key)

cat > /root/boto.cfg <<EOF
[Credentials]
gs_service_key_file = /var/run/secrets/gcs-auth/key

[GSUtil]
default_api_version = 2
default_project_id = $GOOGLE_PROJECT
EOF

echo "CMD: $CMD"

if [ "$CMD" = "dyndns" ]; then
  /admin/scripts/dyn-dns.sh

else
  echo "Unknown command: ${CMD}"
  exit 1
fi
