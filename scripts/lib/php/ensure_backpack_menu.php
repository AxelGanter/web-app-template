<?php

$file = $argv[1] ?? null;

if ($file === null || ! is_file($file)) {
    fwrite(STDERR, "Usage: php ensure_backpack_menu.php <menu_items.blade.php>\n");
    exit(1);
}

$contents = file_get_contents($file);
if ($contents === false) {
    fwrite(STDERR, "Unable to read {$file}\n");
    exit(1);
}

$items = [
    'backpack_url(\'user\')' => '<x-backpack::menu-item title=\'Users\' icon=\'la la-users\' :link="backpack_url(\'user\')" />',
    'backpack_url(\'role\')' => '<x-backpack::menu-item title=\'Roles\' icon=\'la la-id-badge\' :link="backpack_url(\'role\')" />',
    'backpack_url(\'permission\')' => '<x-backpack::menu-item title=\'Permissions\' icon=\'la la-key\' :link="backpack_url(\'permission\')" />',
];

foreach ($items as $needle => $item) {
    if (! str_contains($contents, $needle)) {
        $contents = rtrim($contents).PHP_EOL.$item.PHP_EOL;
    }
}

file_put_contents($file, $contents);
