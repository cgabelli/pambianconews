<?php
/**
 * Pambianconews Staging Sync - Ricevitore DB
 * Endpoint su Hetzner Staging che riceve il dump compresso da produzione e lo importa.
 */

define('SYNC_SECRET', 'PambiancoSync2026SecretKey!');
define('LOG_FILE', '/tmp/pambianco_sync.log');

function log_sync($msg) {
    file_put_contents(LOG_FILE, date('[Y-m-d H:i:s] ') . $msg . "\n", FILE_APPEND);
}

header('Content-Type: application/json');

// Validazione chiave
if (empty($_POST['secret']) || $_POST['secret'] !== SYNC_SECRET) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Accesso non autorizzato.']);
    exit;
}

$db      = $_POST['db']       ?? 'pambianconews_staging';
$dbuser  = $_POST['dbuser']   ?? 'pambianco';
$dbpass  = $_POST['dbpass']   ?? 'Staging2026!Password';
$encoded = $_POST['dump_b64'] ?? ($_POST['dump'] ?? '');

if (empty($encoded)) {
    echo json_encode(['success' => false, 'message' => 'Dump vuoto o non ricevuto.']);
    exit;
}

$gz_data = base64_decode($encoded);
$sql = gzuncompress($gz_data);
if ($sql === false) {
    echo json_encode(['success' => false, 'message' => 'Impossibile decomprimere i dati SQL.']);
    exit;
}

try {
    $mysqli = new mysqli('db', $dbuser, $dbpass, $db);
    if ($mysqli->connect_error) {
        echo json_encode(['success' => false, 'message' => 'Connessione DB fallita: ' . $mysqli->connect_error]);
        exit;
    }

    $mysqli->set_charset('utf8mb4');
    $mysqli->query("SET FOREIGN_KEY_CHECKS=0");
    $mysqli->query("SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO'");

    if ($mysqli->multi_query($sql)) {
        do {
            if ($result = $mysqli->store_result()) {
                $result->free();
            }
        } while ($mysqli->more_results() && $mysqli->next_result());
    }

    if ($mysqli->error) {
        log_sync("Errore multi_query: " . $mysqli->error);
        echo json_encode(['success' => false, 'message' => 'Errore SQL: ' . $mysqli->error]);
    } else {
        log_sync("Import tabella completato!");
        echo json_encode(['success' => true, 'message' => 'Tabella importata con successo nel database Staging.']);
    }

    $mysqli->close();

} catch (Throwable $e) {
    log_sync("Exception: " . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Errore DB: ' . $e->getMessage()]);
}
