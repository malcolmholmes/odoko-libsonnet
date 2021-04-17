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
  echo "RewriteRule . /index.php" > /var/www/html/wp-content/downloads/.htaccess
  echo "Enabling plugins"
  setup_boto
  /wordpress/install-plugins.sh | tee -a /wordpress/install.log
  MU_PLUGINS=/var/www/html/wp-content/mu-plugins
  if [ -f $MU_PLUGINS ]; then rm $MU_PLUGINS; fi
  mkdir -p $MU_PLUGINS
  cp /wordpress/install.php $MU_PLUGINS/
  cp /wordpress/mu-plugins/*.php $MU_PLUGINS/
  (sleep 10 && curl -s localhost/odoko-install && rm $MU_PLUGINS/install.php) &

  echo "Initialising WordPress"
  chown www-data:www-data /var/www/html/wp-content
  /usr/local/bin/docker-entrypoint.sh apache2-foreground
  exit

elif [ "$CMD" = "database" ]; then
  SQL="CREATE DATABASE IF NOT EXISTS \`$WORDPRESS_DB_NAME\`;
  GRANT ALL ON \`$WORDPRESS_DB_NAME\`.* TO \`$WORDPRESS_DB_NAME\`@'%' IDENTIFIED BY '$WORDPRESS_DB_PASSWORD';"
  echo "Creating database $WORDPRESS_DB_NAME"
  echo "With $SQL"
  mysql -uroot -p$WORDPRESS_DB_ROOT_PASSWORD -hmysql.mysql -e "$SQL"
  echo "Done."

else
  echo "Unknown command: $CMD"
fi

