<?php
define('DB_NAME', 'pambianconews_staging');
define('DB_USER', 'pambianco');
define('DB_PASSWORD', 'Staging2026!Password');
define('DB_HOST', 'db');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

$table_prefix = 'wp_';

define('WP_DEBUG', false);
define('WP_ENVIRONMENT_TYPE', 'staging');
define('DISALLOW_INDEXING', true);

define('WP_ALLOW_MULTISITE', true);
define('MULTISITE', true);
define('SUBDOMAIN_INSTALL', true);
define('DOMAIN_CURRENT_SITE', 'staging.pambianconews.com');
define('PATH_CURRENT_SITE', '/');
define('SITE_ID_CURRENT_SITE', 1);
define('BLOG_ID_CURRENT_SITE', 1);

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';
