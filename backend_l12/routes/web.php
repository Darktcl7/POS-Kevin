<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Admin\IngredientController;
use App\Http\Controllers\Admin\ProductController;
use App\Http\Controllers\Admin\UserController;
use App\Http\Controllers\WebAuthController;

Route::redirect('/', '/pos');
Route::redirect('/admin', '/pos');

Route::get('/pos/{any?}', function ($any = '') {
    // If the request matches an actual file on disk, let the server serve it directly
    $filePath = public_path('pos/' . $any);
    if ($any && file_exists($filePath) && !is_dir($filePath)) {
        $mime = match(pathinfo($filePath, PATHINFO_EXTENSION)) {
            'js' => 'application/javascript',
            'css' => 'text/css',
            'json' => 'application/json',
            'png' => 'image/png',
            'jpg', 'jpeg' => 'image/jpeg',
            'svg' => 'image/svg+xml',
            'ico' => 'image/x-icon',
            'woff' => 'font/woff',
            'woff2' => 'font/woff2',
            'ttf' => 'font/ttf',
            'otf' => 'font/otf',
            'wasm' => 'application/wasm',
            default => 'application/octet-stream',
        };
        return response()->file($filePath, ['Content-Type' => $mime]);
    }
    // For all other routes, serve the Flutter SPA index.html
    return response(file_get_contents(public_path('pos/index.html')), 200)
        ->header('Content-Type', 'text/html');
})->where('any', '.*');
