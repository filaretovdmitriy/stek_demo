<?php

declare(strict_types=1);

function readRoutes(string $filePath): array
{
    $handle = fopen($filePath, 'rb');
    $routes = [];

    while (($values = fgetcsv($handle, 0, ';')) !== false) {
        [$startId, $description, $endId] = array_map('trim', $values);

        $routes[] = [
            'start_id' => $startId,
            'description' => $description,
            'end_id' => $endId === '' ? null : $endId,
        ];
    }

    fclose($handle);

    return $routes;
}

function findRoutesWithUnusedStart(array $routes): array
{
    $usedEndIds = [];

    foreach ($routes as $route) {
        if ($route['end_id'] !== null) {
            $usedEndIds[$route['end_id']] = true;
        }
    }

    return array_values(array_filter(
        $routes,
        static fn (array $route): bool =>
            !isset($usedEndIds[$route['start_id']])
    ));
}

function buildRoute(array $routes, string $startId): array
{
    $routesByStartId = [];

    foreach ($routes as $route) {
        $routesByStartId[$route['start_id']] = $route;
    }

    $descriptions = [];
    $currentId = $startId;

    while (isset($routesByStartId[$currentId])) {
        $route = $routesByStartId[$currentId];
        $descriptions[] = $route['description'];
        $currentId = $route['end_id'];
    }

    return [count($descriptions), $descriptions];
}

function findLongestRoute(array $routes): array
{
    $longestRoute = $routes[0];

    foreach ($routes as $route) {
        if ($route[0] > $longestRoute[0]) {
            $longestRoute = $route;
        }
    }

    return $longestRoute;
}

$routes = readRoutes(__DIR__ . '/routes.txt');
$routesWithUnusedStart = findRoutesWithUnusedStart($routes);
$builtRoutes = [];

foreach ($routesWithUnusedStart as $route) {
    $builtRoutes[] = buildRoute($routes, $route['start_id']);
}

[, $longestDescriptions] = findLongestRoute($builtRoutes);

$longestRouteText =
    implode(' -> ', $longestDescriptions)
    . "\n";

file_put_contents(__DIR__ . '/longest-route.txt', $longestRouteText);
