<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$dataFile = __DIR__ . '/data/views.json';

$data = [];
if (file_exists($dataFile)) {
    $raw = json_decode(file_get_contents($dataFile), true);
    if (is_array($raw)) $data = $raw;
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

// ── Events (button/link clicks) — stored inside views.json under each day['events']
$eventsToday = [];
$events30 = [];
$eventsAll = [];

$cutoff30 = date('Y-m-d', strtotime('-29 days'));
foreach ($data as $d => $dayBlock) {
    if (!isset($dayBlock['events']) || !is_array($dayBlock['events'])) continue;
    $in30 = ($d >= $cutoff30);
    foreach ($dayBlock['events'] as $evName => $info) {
        $c = isset($info['count']) ? (int)$info['count'] : 0;
        if ($c <= 0) continue;
        if ($d === $today) $eventsToday[$evName] = ($eventsToday[$evName] ?? 0) + $c;
        if ($in30) $events30[$evName] = ($events30[$evName] ?? 0) + $c;
        $eventsAll[$evName] = ($eventsAll[$evName] ?? 0) + $c;
    }
}

// Fallback: also read legacy separate data/events.json (if it has old clicks)
$eventsFile = __DIR__ . '/data/events.json';
if (file_exists($eventsFile)) {
    $evData = json_decode(file_get_contents($eventsFile), true);
    if (is_array($evData)) {
        foreach ($evData as $d => $dayBlock) {
            if (!isset($dayBlock['events']) || !is_array($dayBlock['events'])) continue;
            $in30 = ($d >= $cutoff30);
            foreach ($dayBlock['events'] as $evName => $info) {
                $c = isset($info['count']) ? (int)$info['count'] : 0;
                if ($c <= 0) continue;
                if ($d === $today) $eventsToday[$evName] = ($eventsToday[$evName] ?? 0) + $c;
                if ($in30) $events30[$evName] = ($events30[$evName] ?? 0) + $c;
                $eventsAll[$evName] = ($eventsAll[$evName] ?? 0) + $c;
            }
        }
    }
}

echo json_encode([
    'total' => $total,
    'today' => $todayCount,
    'days' => $days,
    'events' => [
        'today' => $eventsToday,
        'last30' => $events30,
        'all' => $eventsAll
    ]
]);
