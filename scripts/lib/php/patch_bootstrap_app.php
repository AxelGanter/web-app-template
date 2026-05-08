<?php

$file = $argv[1] ?? null;

if ($file === null || ! is_file($file)) {
    fwrite(STDERR, "Usage: php patch_bootstrap_app.php <bootstrap-app.php>\n");
    exit(1);
}

$contents = file_get_contents($file);

if ($contents === false) {
    fwrite(STDERR, "Unable to read {$file}\n");
    exit(1);
}

if (! str_contains($contents, 'use Illuminate\Http\Request;')) {
    $contents = str_replace(
        "use Illuminate\Foundation\Configuration\Middleware;\n",
        "use Illuminate\Foundation\Configuration\Middleware;\nuse Illuminate\Http\Request;\n",
        $contents
    );
}

$middlewareBlock = <<<'BLOCK'
->withMiddleware(function (Middleware $middleware): void {
        //
    })
BLOCK;

$middlewareReplacement = <<<'BLOCK'
->withMiddleware(function (Middleware $middleware): void {
        $middleware->statefulApi();
        $middleware->redirectGuestsTo(function (Request $request): ?string {
            return $request->is('api/*') ? null : '/admin/login';
        });
    })
BLOCK;

if (str_contains($contents, $middlewareBlock) && ! str_contains($contents, '$middleware->statefulApi();')) {
    $contents = str_replace($middlewareBlock, $middlewareReplacement, $contents);
}

$exceptionsBlock = <<<'BLOCK'
->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
BLOCK;

$exceptionsReplacement = <<<'BLOCK'
->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(function (Request $request): bool {
            return $request->is('api/*') || $request->expectsJson();
        });
    })->create();
BLOCK;

if (str_contains($contents, $exceptionsBlock) && ! str_contains($contents, 'shouldRenderJsonWhen')) {
    $contents = str_replace($exceptionsBlock, $exceptionsReplacement, $contents);
}

if (! str_contains($contents, '$middleware->statefulApi();')) {
    fwrite(STDERR, "Unable to enable statefulApi() in {$file}\n");
    exit(1);
}

if (! str_contains($contents, 'shouldRenderJsonWhen')) {
    fwrite(STDERR, "Unable to enforce JSON API exceptions in {$file}\n");
    exit(1);
}

file_put_contents($file, $contents);
