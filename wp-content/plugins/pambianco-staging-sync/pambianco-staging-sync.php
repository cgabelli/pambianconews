<?php
/**
 * Plugin Name: Pambianconews Staging Sync (Custom & Free)
 * Description: Plugin custom ed in-house per la sincronizzazione del database di Produzione su Staging Hetzner. Zero abbonamenti, zero dipendenze esterne.
 * Version: 3.0.0
 * Author: Team Pambianconews
 * Network: true
 */

if (!defined('ABSPATH')) exit;

define('PAMBIANCO_STAGING_HOST',    '188.34.207.45');
define('PAMBIANCO_STAGING_DB',      'pambianconews_staging');
define('PAMBIANCO_STAGING_DB_USER', 'pambianco');
define('PAMBIANCO_STAGING_DB_PASS', 'Staging2026!Password');
define('PAMBIANCO_STAGING_SECRET',  'PambiancoSync2026SecretKey!');

define('PAMBIANCO_DOMAIN_MAP', serialize([
    'www.pambianconews.com'         => 'staging.pambianconews.com',
    'moda.pambianconews.com'        => 'moda.staging.pambianconews.com',
    'design.pambianconews.com'      => 'design.staging.pambianconews.com',
    'beauty.pambianconews.com'      => 'beauty.staging.pambianconews.com',
    'winefood.pambianconews.com'    => 'winefood.staging.pambianconews.com',
    'hotellerie.pambianconews.com'  => 'hotellerie.staging.pambianconews.com',
    'magazine.pambianconews.com'    => 'magazine.staging.pambianconews.com',
]));

class PambiancoStagingSync {

    public function __construct() {
        add_action('network_admin_menu', [$this, 'add_network_menu']);
        add_action('wp_ajax_pambianco_get_tables', [$this, 'ajax_get_tables']);
        add_action('wp_ajax_pambianco_sync_table', [$this, 'ajax_sync_table']);
        add_action('wp_ajax_pambianco_sync_table_chunk', [$this, 'ajax_sync_table_chunk']);
        add_action('wp_ajax_pambianco_sync_theme', [$this, 'ajax_sync_theme']);
        add_action('wp_ajax_pambianco_sync_specific_posts', [$this, 'ajax_sync_specific_posts']);
    }

    public function add_network_menu() {
        add_submenu_page(
            'settings.php',
            'Pambianconews Staging Sync',
            'Staging Sync (In-House)',
            'manage_network_options',
            'pambianco-staging-sync',
            [$this, 'render_admin_page']
        );
    }

    public function render_admin_page() {
        $prod_db   = DB_NAME;
        $prod_host = DB_HOST;
        $staging   = PAMBIANCO_STAGING_HOST;
        ?>
        <div class="wrap">
            <h1>🚀 Pambianconews Staging Sync (In-House) v3.0</h1>
            <p>Strumento proprietario per sincronizzare il database di Produzione (<strong><?php echo esc_html($prod_db); ?></strong>) sull'ambiente Staging Hetzner (<strong><?php echo esc_html($staging); ?></strong>).</p>
            <div class="card" style="max-width:640px;padding:20px;margin-top:20px;">
                <h2>🔄 Sincronizzazione Database & Temi</h2>
                <button id="pambianco-sync-btn" class="button button-primary button-hero">Avvia Sincronizzazione Ora</button>
                <div id="sync-status-output" style="margin-top:15px;font-family:monospace;background:#f0f0f0;padding:12px;border-radius:4px;display:none;white-space:pre-wrap;max-height:300px;overflow-y:auto;"></div>
            </div>
        </div>
        <?php
    }

    public function ajax_get_tables() {
        if (!current_user_can('manage_network_options') || !check_ajax_referer('pambianco_sync', false, false)) {
            wp_send_json_error(['message' => 'Non autorizzato.']);
        }
        global $wpdb;
        $all = $wpdb->get_col('SHOW TABLES');
        $filtered = array_values(array_filter($all, function($t) {
            return !preg_match('/(actionscheduler_logs|wflogs|wfhits|redirection_logs|cerber_|borlabs_cookie_log)/i', $t);
        }));
        wp_send_json_success(['tables' => $filtered]);
    }

    public function ajax_sync_table() {
        @set_time_limit(300);
        if (!current_user_can('manage_network_options') || !check_ajax_referer('pambianco_sync', false, false)) {
            wp_send_json_error(['message' => 'Non autorizzato.']);
        }

        $table = sanitize_text_field($_POST['table'] ?? '');
        if (empty($table)) {
            wp_send_json_error(['message' => 'Tabella non specificata.']);
        }

        global $wpdb;
        $domain_map = unserialize(PAMBIANCO_DOMAIN_MAP);

        $sql = "SET FOREIGN_KEY_CHECKS=0;\nSET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';\nSET NAMES utf8mb4;\n";
        $create = $wpdb->get_row("SHOW CREATE TABLE `{$table}`", ARRAY_N);
        if (!empty($create[1])) {
            $sql .= "DROP TABLE IF EXISTS `{$table}`;\n" . $create[1] . ";\n";
        }

        $total = (int) $wpdb->get_var("SELECT COUNT(*) FROM `{$table}`");
        $offset = 0;
        $batch = 200;

        while ($offset < $total) {
            $rows = $wpdb->get_results("SELECT * FROM `{$table}` LIMIT {$offset}, {$batch}", ARRAY_A);
            if (empty($rows)) break;

            $columns = '`' . implode('`, `', array_keys($rows[0])) . '`';
            $chunk = [];

            foreach ($rows as $row) {
                $vals = array_map(function($v) use ($domain_map) {
                    if ($v === null) return 'NULL';
                    foreach ($domain_map as $p_dom => $s_dom) {
                        if (is_string($v) && strpos($v, $p_dom) !== false) {
                            $v = str_replace($p_dom, $s_dom, $v);
                        }
                    }
                    return "'" . addslashes($v) . "'";
                }, array_values($row));
                $chunk[] = '(' . implode(', ', $vals) . ')';
            }

            if (!empty($chunk)) {
                $sql .= "INSERT INTO `{$table}` ({$columns}) VALUES\n" . implode(",\n", $chunk) . ";\n";
            }
            $offset += $batch;
        }

        $sql .= "SET FOREIGN_KEY_CHECKS=1;\n";

        $receiver_url = 'https://' . PAMBIANCO_STAGING_HOST . '/pambianco-sync-receiver.php';
        $res = wp_remote_post($receiver_url, [
            'timeout'   => 120,
            'sslverify' => false,
            'body'      => [
                'secret'   => PAMBIANCO_STAGING_SECRET,
                'dump_b64' => base64_encode(gzcompress($sql, 6)),
                'db'       => PAMBIANCO_STAGING_DB,
                'dbuser'   => PAMBIANCO_STAGING_DB_USER,
                'dbpass'   => PAMBIANCO_STAGING_DB_PASS,
            ],
        ]);

        if (is_wp_error($res)) {
            wp_send_json_error(['message' => $res->get_error_message()]);
        }

        $body = json_decode(wp_remote_retrieve_body($res), true);
        if (!empty($body['success'])) {
            wp_send_json_success(['message' => "Tabella `{$table}` sincronizzata"]);
        } else {
            wp_send_json_error(['message' => $body['message'] ?? 'Errore su Hetzner']);
        }
    }

    public function ajax_sync_table_chunk() {
        @set_time_limit(300);
        if (!current_user_can('manage_network_options') || !check_ajax_referer('pambianco_sync', false, false)) {
            wp_send_json_error(['message' => 'Non autorizzato.']);
        }

        $table  = sanitize_text_field($_POST['table'] ?? '');
        $offset = intval($_POST['offset'] ?? 0);
        $limit  = intval($_POST['limit'] ?? 500);

        if (empty($table)) {
            wp_send_json_error(['message' => 'Tabella non specificata.']);
        }

        global $wpdb;
        $domain_map = unserialize(PAMBIANCO_DOMAIN_MAP);

        $sql = "SET FOREIGN_KEY_CHECKS=0;\nSET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';\nSET NAMES utf8mb4;\n";

        if ($offset === 0) {
            $create = $wpdb->get_row("SHOW CREATE TABLE `{$table}`", ARRAY_N);
            if (!empty($create[1])) {
                $sql .= "DROP TABLE IF EXISTS `{$table}`;\n" . $create[1] . ";\n";
            }
        }

        $rows = $wpdb->get_results("SELECT * FROM `{$table}` LIMIT {$offset}, {$limit}", ARRAY_A);
        if (!empty($rows)) {
            $columns = '`' . implode('`, `', array_keys($rows[0])) . '`';
            $chunk = [];
            foreach ($rows as $row) {
                $vals = array_map(function($v) use ($domain_map) {
                    if ($v === null) return 'NULL';
                    foreach ($domain_map as $p_dom => $s_dom) {
                        if (is_string($v) && strpos($v, $p_dom) !== false) {
                            $v = str_replace($p_dom, $s_dom, $v);
                        }
                    }
                    return "'" . addslashes($v) . "'";
                }, array_values($row));
                $chunk[] = '(' . implode(', ', $vals) . ')';
            }
            $sql .= "INSERT INTO `{$table}` ({$columns}) VALUES\n" . implode(",\n", $chunk) . ";\n";
        }

        $sql .= "SET FOREIGN_KEY_CHECKS=1;\n";

        $receiver_url = 'https://' . PAMBIANCO_STAGING_HOST . '/pambianco-sync-receiver.php';
        $res = wp_remote_post($receiver_url, [
            'timeout'   => 120,
            'sslverify' => false,
            'body'      => [
                'secret'   => PAMBIANCO_STAGING_SECRET,
                'dump_b64' => base64_encode(gzcompress($sql, 6)),
                'db'       => PAMBIANCO_STAGING_DB,
                'dbuser'   => PAMBIANCO_STAGING_DB_USER,
                'dbpass'   => PAMBIANCO_STAGING_DB_PASS,
            ],
        ]);

        if (is_wp_error($res)) {
            wp_send_json_error(['message' => $res->get_error_message()]);
        }

        $total = (int) $wpdb->get_var("SELECT COUNT(*) FROM `{$table}`");
        $next = $offset + count($rows);
        $has_more = $next < $total;

        wp_send_json_success([
            'table'       => $table,
            'synced'      => count($rows),
            'next_offset' => $next,
            'total'       => $total,
            'has_more'    => $has_more
        ]);
    }

    public function ajax_sync_theme() {
        @set_time_limit(600);
        if (!current_user_can('manage_network_options') || !check_ajax_referer('pambianco_sync', false, false)) {
            wp_send_json_error(['message' => 'Non autorizzato.']);
        }

        $theme_slug = sanitize_text_field($_POST['theme'] ?? 'jnews');
        $theme_dir  = get_theme_root() . '/' . $theme_slug;

        if (!file_exists($theme_dir)) {
            wp_send_json_error(['message' => "Cartella tema {$theme_slug} non trovata in {$theme_dir}"]);
        }

        $tmp_zip = tempnam(sys_get_temp_dir(), 'theme_') . '.zip';
        $zip = new ZipArchive();
        if ($zip->open($tmp_zip, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== TRUE) {
            wp_send_json_error(['message' => 'Impossibile creare archivio zip del tema.']);
        }

        $files = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($theme_dir),
            RecursiveIteratorIterator::LEAVES_ONLY
        );

        foreach ($files as $name => $file) {
            if (!$file->isDir()) {
                $filePath = $file->getRealPath();
                $relativePath = $theme_slug . '/' . substr($filePath, strlen($theme_dir) + 1);
                $zip->addFile($filePath, $relativePath);
            }
        }
        $zip->close();

        $zip_b64 = base64_encode(file_get_contents($tmp_zip));
        @unlink($tmp_zip);

        $receiver_url = 'https://' . PAMBIANCO_STAGING_HOST . '/pambianco-file-receiver.php';
        $res = wp_remote_post($receiver_url, [
            'timeout'   => 300,
            'sslverify' => false,
            'body'      => [
                'secret'   => PAMBIANCO_STAGING_SECRET,
                'type'     => 'theme',
                'filename' => $theme_slug . '.zip',
                'zip_b64'  => $zip_b64
            ],
        ]);

        if (is_wp_error($res)) {
            wp_send_json_error(['message' => 'Errore invio tema: ' . $res->get_error_message()]);
        }

        $body = json_decode(wp_remote_retrieve_body($res), true);
        if (!empty($body['success'])) {
            wp_send_json_success(['message' => "Tema `{$theme_slug}` sincronizzato con successo su Staging!"]);
        } else {
            wp_send_json_error(['message' => $body['message'] ?? 'Errore ricezione tema su Hetzner']);
        }
    }

    public function ajax_sync_specific_posts() {
        @set_time_limit(300);
        if (!current_user_can('manage_network_options') || !check_ajax_referer('pambianco_sync', false, false)) {
            wp_send_json_error(['message' => 'Non autorizzato.']);
        }

        $ids_str = sanitize_text_field($_POST['ids'] ?? '178901');
        $ids = array_filter(array_map('intval', explode(',', $ids_str)));
        if (empty($ids)) {
            wp_send_json_error(['message' => 'Nessun ID specificato.']);
        }

        global $wpdb;
        $domain_map = unserialize(PAMBIANCO_DOMAIN_MAP);

        $id_list = implode(',', $ids);
        $posts = $wpdb->get_results("SELECT * FROM {$wpdb->posts} WHERE ID IN ({$id_list})", ARRAY_A);
        $postmeta = $wpdb->get_results("SELECT * FROM {$wpdb->postmeta} WHERE post_id IN ({$id_list})", ARRAY_A);

        $sql = "SET FOREIGN_KEY_CHECKS=0;\nSET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';\nSET NAMES utf8mb4;\n";

        if (!empty($posts)) {
            $cols = '`' . implode('`, `', array_keys($posts[0])) . '`';
            $p_vals = [];
            foreach ($posts as $p) {
                $row = array_map(function($v) use ($domain_map) {
                    if ($v === null) return 'NULL';
                    foreach ($domain_map as $p_dom => $s_dom) {
                        if (is_string($v) && strpos($v, $p_dom) !== false) $v = str_replace($p_dom, $s_dom, $v);
                    }
                    return "'" . addslashes($v) . "'";
                }, array_values($p));
                $p_vals[] = '(' . implode(', ', $row) . ')';
            }
            $sql .= "REPLACE INTO `wp_posts` ({$cols}) VALUES\n" . implode(",\n", $p_vals) . ";\n";
        }

        if (!empty($postmeta)) {
            $m_cols = '`' . implode('`, `', array_keys($postmeta[0])) . '`';
            $m_vals = [];
            foreach ($postmeta as $m) {
                $row = array_map(function($v) use ($domain_map) {
                    if ($v === null) return 'NULL';
                    foreach ($domain_map as $p_dom => $s_dom) {
                        if (is_string($v) && strpos($v, $p_dom) !== false) $v = str_replace($p_dom, $s_dom, $v);
                    }
                    return "'" . addslashes($v) . "'";
                }, array_values($m));
                $m_vals[] = '(' . implode(', ', $row) . ')';
            }
            $sql .= "REPLACE INTO `wp_postmeta` ({$m_cols}) VALUES\n" . implode(",\n", $m_vals) . ";\n";
        }

        $sql .= "SET FOREIGN_KEY_CHECKS=1;\n";

        $receiver_url = 'https://' . PAMBIANCO_STAGING_HOST . '/pambianco-sync-receiver.php';
        $res = wp_remote_post($receiver_url, [
            'timeout'   => 60,
            'sslverify' => false,
            'body'      => [
                'secret'   => PAMBIANCO_STAGING_SECRET,
                'dump_b64' => base64_encode(gzcompress($sql, 6)),
                'db'       => PAMBIANCO_STAGING_DB,
                'dbuser'   => PAMBIANCO_STAGING_DB_USER,
                'dbpass'   => PAMBIANCO_STAGING_DB_PASS,
            ],
        ]);

        if (is_wp_error($res)) {
            wp_send_json_error(['message' => $res->get_error_message()]);
        }

        wp_send_json_success(['message' => 'Post e metadati sincronizzati con successo.']);
    }
}

new PambiancoStagingSync();
