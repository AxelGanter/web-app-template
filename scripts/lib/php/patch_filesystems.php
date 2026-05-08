<?php

$file = $argv[1] ?? null;

if ($file === null || ! is_file($file)) {
    fwrite(STDERR, "Usage: php patch_filesystems.php <filesystems.php>\n");
    exit(1);
}

$contents = file_get_contents($file);

if ($contents === false) {
    fwrite(STDERR, "Unable to read {$file}\n");
    exit(1);
}

if (str_contains($contents, "'backups' => [")) {
    exit(0);
}

$insert = <<<'BLOCK'

        'backups' => [
            'driver' => 'local',
            'root' => storage_path('backups'),
            'throw' => false,
            'report' => false,
        ],

        'storage' => [
            'driver' => 'local',
            'root' => storage_path(),
            'throw' => false,
            'report' => false,
        ],
BLOCK;

$marker = <<<'BLOCK'
    ],

    /*
    |--------------------------------------------------------------------------
    | Symbolic Links
BLOCK;

if (! str_contains($contents, $marker)) {
    fwrite(STDERR, "Unable to find disks section in {$file}\n");
    exit(1);
}

file_put_contents($file, str_replace($marker, $insert.$marker, $contents));
