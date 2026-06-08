<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$dataFile = __DIR__ . '/data/views.json';

$ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['HTTP_CF_CONNECTING_IP'] ?? $_SERVER['REMOTE_ADDR'] ?? '';
$ip = trim(explode(',', $ip)[0]);

$today = date('Y-m-d');
// Hash IP + date so the same IP on different days is a new entry, and the raw IP is never stored
$ipHash = hash('sha256', $ip . $today . 'ccnotify-salt');

$fp = fopen($dataFile, 'c+');
if (!$fp) {
    http_response_code(500);
    echo json_encode(['error' => 'cannot open data file']);
    exit;
}

flock($fp, LOCK_EX);

$raw = stream_get_contents($fp);
$data = $raw ? json_decode($raw, true) : [];
if (!is_array($data)) $data = [];

// Init today's entry
if (!isset($data[$today])) {
    $data[$today] = ['unique' => 0, 'ips' => []];
}

$isNew = !in_array($ipHash, $data[$today]['ips'], true);
if ($isNew) {
    $data[$today]['ips'][] = $ipHash;
    $data[$today]['unique']++;
}

// Drop entries older than 90 days
$cutoff = date('Y-m-d', strtotime('-90 days'));
foreach (array_keys($data) as $day) {
    if ($day < $cutoff) unset($data[$day]);
}

rewind($fp);
ftruncate($fp, 0);
fwrite($fp, json_encode($data));
flock($fp, LOCK_UN);
fclose($fp);

echo json_encode(['date' => $today, 'unique_today' => $data[$today]['unique'], 'new' => $isNew]);
