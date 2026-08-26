<?php
/**
 * Dynamic wp-config.php for Pambianconews MultiSite (Environment Aware)
 */

// Load environment variables if .env exists
if (file_exists(__DIR__ . '/.env')) {
    $env_lines = file(__DIR__ . '/.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($env_lines as $line) {
        if (strpos(trim($line), '#') === 0) continue;
        list($name, $value) = explode('=', $line, 2);
        $_ENV[trim($name)] = trim($value);
    }
}

// Environment Helper
function env($key, $default = null) {
    return isset($_ENV[$key]) ? $_ENV[$key] : getenv($key) ?: $default;
}

// Database settings
define('DB_NAME', env('DB_NAME', 'pambianconews_db'));
define('DB_USER', env('DB_USER', 'root'));
define('DB_PASSWORD', env('DB_PASSWORD', 'root'));
define('DB_HOST', env('DB_HOST', 'localhost'));
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

$table_prefix = env('DB_PREFIX', 'wp_');

// Authentication Unique Keys and Salts
define('AUTH_KEY',         env('AUTH_KEY', 'put-your-unique-phrase-here'));
define('SECURE_AUTH_KEY',  env('SECURE_AUTH_KEY', 'put-your-unique-phrase-here'));
define('LOGGED_IN_KEY',    env('LOGGED_IN_KEY', 'put-your-unique-phrase-here'));
define('NONCE_KEY',        env('NONCE_KEY', 'put-your-unique-phrase-here'));
define('AUTH_SALT',        env('AUTH_SALT', 'put-your-unique-phrase-here'));
define('SECURE_AUTH_SALT', env('SECURE_AUTH_SALT', 'put-your-unique-phrase-here'));
define('LOGGED_IN_SALT',   env('LOGGED_IN_SALT', 'put-your-unique-phrase-here'));
define('NONCE_SALT',       env('NONCE_SALT', 'put-your-unique-phrase-here'));

// WordPress MultiSite Network Configuration
define('MULTISITE', true);
define('SUBDOMAIN_INSTALL', true);
define('DOMAIN_CURRENT_SITE', env('DOMAIN_CURRENT_SITE', 'staging.pambianconews.com'));
define('PATH_CURRENT_SITE', '/');
define('SITE_ID_CURRENT_SITE', 1);
define('BLOG_ID_CURRENT_SITE', 1);

// Dynamic URLs for Staging / Prod
if (env('WP_HOME')) {
    define('WP_HOME', env('WP_HOME'));
    define('WP_SITEURL', env('WP_SITEURL'));
}

// Environment specific settings
define('WP_ENVIRONMENT_TYPE', env('WP_ENVIRONMENT_TYPE', 'production'));

if (WP_ENVIRONMENT_TYPE === 'staging' || WP_ENVIRONMENT_TYPE === 'development') {
    define('WP_DEBUG', true);
    define('WP_DEBUG_LOG', true);
    define('WP_DEBUG_DISPLAY', false);
    define('DISALLOW_INDEXING', true); // Prevent search engines indexing staging network
    define('AUTOMATIC_UPDATER_DISABLED', true);
} else {
    define('WP_DEBUG', false);
    define('WP_DEBUG_LOG', false);
    define('WP_DEBUG_DISPLAY', false);
}

/* Absolute path to the WordPress directory. */
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';
