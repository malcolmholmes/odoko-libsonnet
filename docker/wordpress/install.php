<?php

/**
 * Plugin Name: Odoko Install
 * Plugin URI: https://github.com/malcolmholmes/odoko-libsonnet/docker/wordpress/install.php
 * Description: Installer for WordPress Plugins
 * Version: 1.0.0
 * Author: Malcolm Holmes
 * Author URI: https://github.com/malcolmholmes
 * License: Proprietary
 * Text Domain: odoko-installer
 */

function odoko_install() {
	$url_path = trim(parse_url(add_query_arg(array()), PHP_URL_PATH), '/');
	if ($url_path == "odoko-install") {
		header("Content-type: text/plain");
		$plugin_file=getenv("PLUGINS_FILE");
		$string = file_get_contents($plugin_file);
		$json = json_decode($string, true);
		$plugins = array_column($json["plugins"], 'module');
		$theme=$json["current_theme"];

        include_once(ABSPATH.'wp-admin/includes/plugin.php');
        if( is_plugin_active("odoko-healthcheck.php")) {
			deactivate_plugins("odoko-healthcheck.php");
		}
		foreach ($plugins as $plugin) {
			activate_plugin($plugin);
			echo "$plugin activated\n";
		}
		switch_theme($theme);
		echo "Switched to theme $theme\n";
		echo "Done.";
		exit();
	}
}

add_action('init', 'odoko_install');
