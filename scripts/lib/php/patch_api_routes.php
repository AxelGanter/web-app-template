<?php

$file = $argv[1] ?? null;

if ($file === null || ! is_file($file)) {
    fwrite(STDERR, "Usage: php patch_api_routes.php <api-routes.php>\n");
    exit(1);
}

$contents = file_get_contents($file);

if ($contents === false) {
    fwrite(STDERR, "Unable to read {$file}\n");
    exit(1);
}

if (! str_contains($contents, 'use App\Http\Controllers\Api\AuthController;')) {
    $contents = str_replace(
        "<?php\n\n",
        "<?php\n\nuse App\Http\Controllers\Api\AuthController;\n",
        $contents
    );
}

$routes = <<<'BLOCK'

Route::post('/auth/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/auth/user', [AuthController::class, 'user']);
});
BLOCK;

if (! str_contains($contents, "Route::post('/auth/login', [AuthController::class, 'login']);")) {
    $contents .= $routes."\n";
}

file_put_contents($file, $contents);
