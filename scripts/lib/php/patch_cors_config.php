<?php

$file = $argv[1] ?? null;

if ($file === null || ! is_file($file)) {
    fwrite(STDERR, "Usage: php patch_cors_config.php <cors.php>\n");
    exit(1);
}

$contents = file_get_contents($file);
if ($contents === false) {
    fwrite(STDERR, "Unable to read {$file}\n");
    exit(1);
}

if (str_contains($contents, "env('FRONTEND_APP_URL'")) {
    exit(0);
}

$replacement = <<<'PHP'
'allowed_origins' => array_values(array_unique(array_filter([
        env('FRONTEND_APP_URL', 'http://localhost:3101'),
        env('FRONTEND_APP_URL_127', 'http://127.0.0.1:3101'),
    ])))
PHP;

$updated = preg_replace("/'allowed_origins'\\s*=>\\s*\\[.*?\\]/s", $replacement, $contents, 1, $count);
if ($updated === null || $count !== 1) {
    fwrite(STDERR, "Unable to patch CORS origins in {$file}\n");
    exit(1);
}

file_put_contents($file, $updated);
