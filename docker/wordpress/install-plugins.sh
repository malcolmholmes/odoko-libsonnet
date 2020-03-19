#!/bin/bash

PLUGINS_FILE=${PLUGINS_FILE?"PLUGINS_FILE required"}

cd /wordpress

mkdir -p /usr/src/wordpress/wp-content/plugins
mkdir -p /wordpress/downloaded-plugins
for PLUGIN_URL in $(jq -r '.plugins[].url' $PLUGINS_FILE); do
  echo "Installing plugin $PLUGIN_URL..."
  ZIP_FILE=/wordpress/downloaded-plugins/$(basename $PLUGIN_URL)
  if [ -e $ZIP_FILE ]; then
    echo "  $ZIP_FILE exists - skipping"
    continue
  elif [[ $PLUGIN_URL =~ ^http ]]; then
    curl -s $PLUGIN_URL > $ZIP_FILE
  elif [[ $PLUGIN_URL =~ ^gs: ]]; then
    gsutil cp $PLUGIN_URL $ZIP_FILE
  else
    echo "  Unknown protocol for $PLUGIN_URL"
    exit
  fi
  unzip -o -d /usr/src/wordpress/wp-content/plugins $ZIP_FILE
done

mkdir -p /usr/src/wordpress/wp-content/themes
mkdir -p /wordpress/downloaded-themes
for THEME_URL in $(jq -r '.themes[].url' $PLUGINS_FILE); do
  echo "Installing theme $THEME_URL..."
  ZIP_FILE=/wordpress/downloaded-themes/$(basename $THEME_URL)
  echo "Looking for $ZIP_FILE"
  if [ -e $ZIP_FILE ]; then
    echo "  $ZIP_FILE exists - skipping"
    continue
  elif [[ $THEME_URL =~ ^http ]]; then
    curl -s $THEME_URL > $ZIP_FILE
  elif [[ $THEME_URL =~ ^gs: ]]; then
    gsutil cp $THEME_URL $ZIP_FILE
  else
    echo "Unknown protocol for $THEME_URL"
    exit
  fi
  unzip -o -d /usr/src/wordpress/wp-content/themes/ $ZIP_FILE
done

echo "Done."
