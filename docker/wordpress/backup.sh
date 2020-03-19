#!/bin/bash

TODAY=`date +%Y-%m-%d-%H:%M:%S`
BUCKET=${BUCKET?"BUCKET required"}
GS_BUCKET=gs://$BUCKET/backups/$WORDPRESS_DB_NAME

function removeBackups {
  APP=$1

  TEN_DAYS_AGO=$(date -d "10 days ago" +%s)
  for FILE in $(gsutil ls $GS_BUCKET/$APP); do
    if [[ $FILE == *"LATEST"* ]]; then
      continue
    fi
    DATESTR=$(echo $FILE | sed "s#.*backups/$WORDPRESS_DB_NAME/$APP/##" | sed "s/-..:.*//")
    echo -n $FILE
    DATE=$(date -d $DATESTR +%s)
    if [[ $DATESTR == *"-01" ]]; then
      echo
      continue
    elif [ $DATE -lt $TEN_DAYS_AGO ]; then
      echo " REMOVE"
      gsutil rm $FILE
    else
      echo
    fi
  done
}

mysqldump -u$WORDPRESS_DB_USER -p$WORDPRESS_DB_PASSWORD -hmysql.mysql $WORDPRESS_DB_NAME \
   | gzip \
   | gsutil cp - $GS_BUCKET/db/$TODAY.sql.gz
echo "$TODAY" | gsutil cp - $GS_BUCKET/db/LATEST

(cd /; tar -cz uploads | gsutil cp - $GS_BUCKET/uploads/$TODAY.tgz)
echo "$TODAY" | gsutil cp - $GS_BUCKET/uploads/LATEST

echo "Removing old backups."
removeBackups db
removeBackups uploads
