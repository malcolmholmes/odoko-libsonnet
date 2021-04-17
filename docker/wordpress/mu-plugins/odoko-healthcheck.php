<?php 
/**
 * Plugin Name: Odoko Healthcheck
 * Plugin URI: https://github.com/malcolmholmes/odoko-libsonnet/docker/healthcheck
 * Description: Healthcheck URL for WordPress
 * Version: 1.0.0
 * Author: Malcolm Holmes
 * Author URI: https://github.com/malcolmholmes
 * License: Proprietary
 * Text Domain: odoko-healthcheck
 */

function odoko_healthcheck() {
	$url_path = trim(parse_url(add_query_arg(array()), PHP_URL_PATH), '/');
	if ($url_path == "healthcheck") {
		header("Content-type: text/plain");
		echo "OKAY";
		exit();
	}
}

add_action('init', 'odoko_healthcheck');
