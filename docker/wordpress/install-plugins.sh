#!/bin/bash

PLUGINS_FILE=${PLUGINS_FILE?"PLUGINS_FILE required"}
DOWNLOADS_DIR=/var/www/html/wp-content/downloads
PLUGIN_ROOT=/usr/src/wordpress/wp-content/plugins

mkdir -p $DOWNLOADS_DIR
mkdir -p $PLUGIN_ROOT
for PLUGIN_URL in $(jq -r '.plugins[].url' $PLUGINS_FILE); do
  echo "Installing plugin $PLUGIN_URL..."
  ZIP_FILE=$DOWNLOADS_DIR/$(basename $PLUGIN_URL)
  echo "Checking for $ZIP_FILE.."
  if [ -e $ZIP_FILE ]; then
    echo "  $ZIP_FILE exists - skipping"
    continue
  elif [[ $PLUGIN_URL =~ ^http ]]; then
    curl -sL $PLUGIN_URL > $ZIP_FILE
  elif [[ $PLUGIN_URL =~ ^gs: ]]; then
    gsutil cp $PLUGIN_URL $ZIP_FILE
  else
    echo "  Unknown protocol for $PLUGIN_URL"
    exit
  fi
  unzip -o -q -d /usr/src/wordpress/wp-content/plugins $ZIP_FILE
done
echo "Change ownership and clone plugins"
chown -R www-data:www-data /usr/src/wordpress/wp-content/plugins

echo "Install themes"
mkdir -p /usr/src/wordpress/wp-content/themes
for THEME_URL in $(jq -r '.themes[].url' $PLUGINS_FILE); do
  echo "Installing theme $THEME_URL..."
  ZIP_FILE=/$DOWNLOADS_DIR/$(basename $THEME_URL)
  echo "Looking for $ZIP_FILE"
  if [ -e $ZIP_FILE ]; then
    echo "  $ZIP_FILE exists - skipping"
    continue
  elif [[ $THEME_URL =~ ^http ]]; then
    curl -sL $THEME_URL > $ZIP_FILE
  elif [[ $THEME_URL =~ ^gs: ]]; then
    gsutil cp $THEME_URL $ZIP_FILE
  else
    echo "Unknown protocol for $THEME_URL"
    exit
  fi
  unzip -o -q -d /usr/src/wordpress/wp-content/themes/ $ZIP_FILE
done
chown -R www-data:www-data /usr/src/wordpress/wp-content/themes

echo "Done."
