<?php
/**
 * Pambianconews Staging Sync - Ricevitore File e Temi
 * Endpoint su Hetzner Staging che riceve pacchetti zip di temi e plugin da produzione.
 */

define('SYNC_SECRET', 'PambiancoSync2026SecretKey!');

header('Content-Type: application/json');

if (empty($_POST['secret']) || $_POST['secret'] !== SYNC_SECRET) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Non autorizzato.']);
    exit;
}

$type     = $_POST['type'] ?? 'theme'; // theme o plugin
$target   = ($type === 'plugin') ? '/var/www/html/wp-content/plugins' : '/var/www/html/wp-content/themes';
$zip_b64  = $_POST['zip_b64'] ?? '';
$filename = preg_replace('/[^a-zA-Z0-9_.-]/', '', $_POST['filename'] ?? 'package.zip');

if (empty($zip_b64)) {
    echo json_encode(['success' => false, 'message' => 'Dati file mancanti.']);
    exit;
}

$zip_data = base64_decode($zip_b64);
$tmp_zip  = tempnam('/tmp', 'pkg_') . '.zip';
file_put_contents($tmp_zip, $zip_data);

$zip = new ZipArchive;
if ($zip->open($tmp_zip) === TRUE) {
    @mkdir($target, 0777, true);
    $zip->extractTo($target);
    $zip->close();
    @unlink($tmp_zip);
    echo json_encode(['success' => true, 'message' => "Estratto {$filename} in {$target} con successo."]);
} else {
    @unlink($tmp_zip);
    echo json_encode(['success' => false, 'message' => 'Impossibile estrarre lo zip.']);
}
