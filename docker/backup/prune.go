package main

func pruneBackups(env, app string) error {
	/*
	   TEN_DAYS_AGO=$(date -d "10 days ago" +%s)
	   URL="gs://mouthpiece_store/backups/$APP/$NS"
	   echo "URL: $URL"
	   for FILE in $(gsutil ls $URL); do
	     if [[ $FILE == *"LATEST"* ]]; then
	       continue
	     fi*/
	//DATESTR=$(echo $FILE | sed "s#.*backups/$APP/$NS/##" | sed "s/-..:.*//")
	/*echo -n $FILE
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
	*/
	return nil
}
