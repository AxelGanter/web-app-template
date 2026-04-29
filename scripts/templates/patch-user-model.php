<?php

/**
 * Patches the User model to add CrudTrait and HasRoles.
 * Usage: php patch-user-model.php /path/to/User.php
 */

$path = $argv[1] ?? null;

if ($path === null || !file_exists($path)) {
    fprintf(STDERR, "Usage: php %s <path-to-User.php>\n", $argv[0]);
    exit(1);
}

$contents = file_get_contents($path);

$contents = str_replace(
    "use Database\\Factories\\UserFactory;\n",
    "use Backpack\\CRUD\\app\\Models\\Traits\\CrudTrait;\nuse Database\\Factories\\UserFactory;\n",
    $contents
);

$contents = str_replace(
    "use Illuminate\\Foundation\\Auth\\User as Authenticatable;\n",
    "use Illuminate\\Foundation\\Auth\\User as Authenticatable;\nuse Spatie\\Permission\\Traits\\HasRoles;\n",
    $contents
);

$contents = str_replace(
    "use HasFactory, Notifiable;",
    "use CrudTrait, HasFactory, HasRoles, Notifiable;",
    $contents
);

file_put_contents($path, $contents);
