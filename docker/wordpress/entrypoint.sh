#!/bin/bash

CMD=${CMD?"Command Required"}

setup_boto() {
  cat > /etc/boto.cfg <<EOF
[Credentials]
gs_service_key_file = /var/run/secrets/gcs-auth/key
[Boto]
https_validate_certificates = True
[GSUtil]
default_api_version = 2
default_project_id = $GOOGLE_PROJECT
EOF
}

if [ "$CMD" = "wordpress" ]; then
  echo "Enabling plugins"
  setup_boto
  /wordpress/install-plugins.sh
  php /wordpress/install-plugins.php 

  echo "Initialising WordPress"
  /usr/local/bin/docker-entrypoint.sh apache2-foreground
  exit

elif [ "$CMD" = "database" ]; then
  SQL="CREATE DATABASE IF NOT EXISTS \`$WORDPRESS_DB_NAME\`;
  GRANT ALL ON \`$WORDPRESS_DB_NAME\`.* TO \`$WORDPRESS_DB_NAME\`@'%' IDENTIFIED BY '$WORDPRESS_DB_PASSWORD';"
  echo "Creating database $WORDPRESS_DB_NAME"
  echo "With $SQL"
  mysql -uroot -p$WORDPRESS_DB_ROOT_PASSWORD -hmysql.mysql -e "$SQL"
  echo "Done."

elif [ "$CMD" = "backup" ]; then
  setup_boto
  /wordpress/backup.sh

elif [ "$CMD" = "restore" ]; then
  setup_boto
  /wordpress/restore.sh

else
  echo "Unknown command: $CMD"
fi

