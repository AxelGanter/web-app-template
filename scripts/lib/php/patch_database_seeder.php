<?php

$file = $argv[1] ?? null;

if ($file === null || ! is_file($file)) {
    fwrite(STDERR, "Usage: php patch_database_seeder.php <DatabaseSeeder.php>\n");
    exit(1);
}

$contents = file_get_contents($file);

if ($contents === false) {
    fwrite(STDERR, "Unable to read {$file}\n");
    exit(1);
}

if (! str_contains($contents, 'AuthorizationSeeder::class')) {
    $contents = preg_replace(
        "/(public function run\\(\\): void\\s*\\{\\R)/",
        "$1        \$this->call(AuthorizationSeeder::class);\n",
        $contents,
        1,
    );
}

$updated = preg_replace([
    '/^use App\\\\Models\\\\User;\R/m',
    '/^\s*\/\/ User::factory\(10\)->create\(\);\R/m',
    '/\R\s*User::factory\(\)->create\(\[.*?\]\);/s',
    '/^\s*\$this->call\(AuthorizationSeeder::class\);$/m',
], ['', '', '', '        $this->call(AuthorizationSeeder::class);'], $contents);

if ($updated === null) {
    fwrite(STDERR, "Regex error while updating {$file}\n");
    exit(1);
}

file_put_contents($file, $updated);
