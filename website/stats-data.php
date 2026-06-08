<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$dataFile = __DIR__ . '/data/views.json';

if (!file_exists($dataFile)) {
    echo json_encode(['total' => 0, 'today' => 0, 'days' => []]);
    exit;
}

$data = json_decode(file_get_contents($dataFile), true);
if (!is_array($data)) {
    echo json_encode(['total' => 0, 'today' => 0, 'days' => []]);
    exit;
}

$today = date('Y-m-d');
$todayCount = $data[$today]['unique'] ?? 0;
$total = array_sum(array_column($data, 'unique'));

// Last 30 days for the chart (fill gaps with 0)
$days = [];
for ($i = 29; $i >= 0; $i--) {
    $d = date('Y-m-d', strtotime("-$i days"));
    $days[] = ['date' => $d, 'unique' => $data[$d]['unique'] ?? 0];
}

echo json_encode(['total' => $total, 'today' => $todayCount, 'days' => $days]);
