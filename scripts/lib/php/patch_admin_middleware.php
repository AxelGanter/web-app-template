<?php

$file = $argv[1] ?? null;

if ($file === null || ! is_file($file)) {
    fwrite(STDERR, "Usage: php patch_admin_middleware.php <CheckIfAdmin.php>\n");
    exit(1);
}

$contents = file_get_contents($file);

if ($contents === false) {
    fwrite(STDERR, "Unable to read {$file}\n");
    exit(1);
}

if (str_contains($contents, "hasRole('admin')")) {
    exit(0);
}

$updated = preg_replace(
    '/private function checkIfUserIsAdmin\(\$user\)\s*\{.*?\n\s*\}/s',
    "private function checkIfUserIsAdmin(\$user)\n    {\n        return \$user?->hasRole('admin') === true;\n    }",
    $contents,
    1,
    $count,
);

if ($updated === null || $count !== 1) {
    fwrite(STDERR, "Unable to patch admin middleware in {$file}\n");
    exit(1);
}

file_put_contents($file, $updated);
