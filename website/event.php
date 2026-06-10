<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$name = isset($_GET['name']) ? $_GET['name'] : (isset($_GET['e']) ? $_GET['e'] : '');
$name = trim($name);

// Sanitize: allow only safe chars for event names
if ($name === '' || !preg_match('/^[a-zA-Z0-9_-]{1,64}$/', $name)) {
    http_response_code(400);
    echo json_encode(['error' => 'invalid name']);
    exit;
}

$dataFile = __DIR__ . '/data/views.json';

$dataDir = dirname($dataFile);
if (!is_dir($dataDir)) {
    @mkdir($dataDir, 0775, true);
}

$ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['HTTP_CF_CONNECTING_IP'] ?? $_SERVER['REMOTE_ADDR'] ?? '';
$ip = trim(explode(',', $ip)[0]);

$today = date('Y-m-d');
// Hash IP + date + event so the same IP can't inflate a specific event on the same day.
// Reuse the exact same data file as the proven pageview tracker.
$ipHash = hash('sha256', $ip . $today . $name . 'ccnotify-salt');

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

// Ensure today's bucket exists (preserve existing 'unique'/'ips' from tracker.php)
if (!isset($data[$today])) {
    $data[$today] = ['unique' => 0, 'ips' => []];
}
if (!isset($data[$today]['events'])) {
    $data[$today]['events'] = [];
}
if (!isset($data[$today]['events'][$name])) {
    $data[$today]['events'][$name] = ['count' => 0, 'ips' => []];
}

$isNew = !in_array($ipHash, $data[$today]['events'][$name]['ips'], true);
if ($isNew) {
    $data[$today]['events'][$name]['ips'][] = $ipHash;
    $data[$today]['events'][$name]['count']++;
}

// Drop entries older than 90 days (keep structure compatible with views)
$cutoff = date('Y-m-d', strtotime('-90 days'));
foreach (array_keys($data) as $day) {
    if ($day < $cutoff) unset($data[$day]);
}

rewind($fp);
ftruncate($fp, 0);
fwrite($fp, json_encode($data));
flock($fp, LOCK_UN);
fclose($fp);

echo json_encode([
    'ok' => true,
    'name' => $name,
    'date' => $today,
    'new' => $isNew,
    'count_today' => $data[$today]['events'][$name]['count']
]);
