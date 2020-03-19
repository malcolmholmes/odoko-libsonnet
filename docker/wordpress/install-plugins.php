<?php

$plugin_file=getenv("PLUGINS_FILE");
$string = file_get_contents($plugin_file);
$json = json_decode($string, true);
$plugins = array_column($json["plugins"], 'module');
$theme=$plugins["current_theme"];

$plugins_serialised=serialize($plugins);

$mysqli = new mysqli(getenv('WORDPRESS_DB_HOST'), getenv('WORDPRESS_DB_USER'), getenv('WORDPRESS_DB_PASSWORD'), getenv('WORDPRESS_DB_NAME'));

if ($mysqli->connect_errno) {
    printf("Connect failed: %s\n", $mysqli->connect_error);
    exit();
}
if ($mysqli->query("UPDATE wp_options SET option_value = '$plugins_serialised' WHERE option_name = 'active_plugins';")===TRUE) {
  printf("Plugins activated\n");
}
if ($mysqli->query("UPDATE wp_options SET option_value = '$theme' WHERE option_name = 'current_theme';")===TRUE) {
  printf("Theme installed\n");
}
if ($mysqli->query("UPDATE wp_options SET option_value = 'yes' WHERE option_name = 'current_theme_supports_woocommerce';")===TRUE) {
  printf("Theme woo installed\n");
}
$mysqli->close();

