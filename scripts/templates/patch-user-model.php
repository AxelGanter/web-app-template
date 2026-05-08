<?php

/**
 * Patches the User model for Backpack, PermissionManager, and Sanctum SPA auth.
 * Usage: php patch-user-model.php /path/to/User.php
 */

$path = $argv[1] ?? null;

if ($path === null || !file_exists($path)) {
    fprintf(STDERR, "Usage: php %s <path-to-User.php>\n", $argv[0]);
    exit(1);
}

$contents = file_get_contents($path);

if (! str_contains($contents, 'use Backpack\\CRUD\\app\\Models\\Traits\\CrudTrait;')) {
    $contents = str_replace(
        "use Database\\Factories\\UserFactory;\n",
        "use Backpack\\CRUD\\app\\Models\\Traits\\CrudTrait;\nuse Database\\Factories\\UserFactory;\n",
        $contents
    );
}

if (! str_contains($contents, 'use Laravel\\Sanctum\\HasApiTokens;')) {
    $contents = str_replace(
        "use Illuminate\\Notifications\\Notifiable;\n",
        "use Illuminate\\Notifications\\Notifiable;\nuse Laravel\\Sanctum\\HasApiTokens;\n",
        $contents
    );
}

if (! str_contains($contents, 'use Spatie\\Permission\\Traits\\HasRoles;')) {
    $contents = str_replace(
        "use Illuminate\\Foundation\\Auth\\User as Authenticatable;\n",
        "use Illuminate\\Foundation\\Auth\\User as Authenticatable;\nuse Spatie\\Permission\\Traits\\HasRoles;\n",
        $contents
    );
}

if (str_contains($contents, 'use HasFactory, Notifiable;')) {
    $contents = str_replace(
        'use HasFactory, Notifiable;',
        'use HasApiTokens, CrudTrait, HasFactory, HasRoles, Notifiable;',
        $contents
    );
}

file_put_contents($path, $contents);
