#!/bin/sh

BUCKET=${BUCKET?"BUCKET required"}

GS_BUCKET=gs://$BUCKET/backups/$WORDPRESS_DB_NAME

LATEST=$(gsutil cp $GS_BUCKET/db/LATEST -)
echo "Restoring database from $LATEST..."
gsutil cp $GS_BUCKET/db/$LATEST.sql.gz - \
  | gunzip \
  | mysql -u$WORDPRESS_DB_USER -p$WORDPRESS_DB_PASSWORD -hmysql.mysql $WORDPRESS_DB_NAME

echo "Unzipping uploads..."
LATEST=$(gsutil cp $GS_BUCKET/uploads/LATEST -)
(cd /; gsutil cp $GS_BUCKET/uploads/$LATEST.tgz - | tar -xz)

echo "Done."
