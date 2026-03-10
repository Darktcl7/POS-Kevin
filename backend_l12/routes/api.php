<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\PrinterController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\PurchaseController;
use App\Http\Controllers\Api\SaleController;
use App\Http\Controllers\Api\SyncController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\IngredientController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| is assigned the "api" middleware group. Enjoy building your API!
|
*/

Route::post('/auth/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::get('/categories', [ProductController::class, 'categories']);
    Route::get('/products', [ProductController::class, 'index']);
    Route::post('/products', [ProductController::class, 'store']);
    Route::put('/products/{id}', [ProductController::class, 'update']);
    Route::delete('/products/{id}', [ProductController::class, 'destroy']);
    
    Route::get('/dashboard/summary', [DashboardController::class, 'summary']);
    Route::get('/dashboard/sales-trend', [DashboardController::class, 'salesTrend']);
    Route::get('/dashboard/top-products', [DashboardController::class, 'topProducts']);
    Route::get('/dashboard/low-stock', [DashboardController::class, 'lowStock']);

    Route::get('/sales/history', [SaleController::class, 'history']);
    Route::get('/sales/tempo', [SaleController::class, 'tempo']);
    Route::post('/sales', [SaleController::class, 'store']);
    Route::post('/purchases/{purchaseId}/receive', [PurchaseController::class, 'receive']);

    Route::get('/printers', [PrinterController::class, 'index']);
    Route::post('/printers', [PrinterController::class, 'store']);

    Route::get('/users', [UserController::class, 'index']);
    Route::post('/users', [UserController::class, 'store']);
    Route::patch('/users/{id}/toggle', [UserController::class, 'toggleActive']);
    Route::patch('/users/{id}/reset-password', [UserController::class, 'resetPassword']);
    Route::delete('/users/{id}', [UserController::class, 'destroy']);

    Route::get('/ingredients', [IngredientController::class, 'index']);
    Route::post('/ingredients', [IngredientController::class, 'store']);
    Route::post('/ingredients/{id}/stock', [IngredientController::class, 'updateStock']);
    Route::delete('/ingredients/{id}', [IngredientController::class, 'destroy']);

    Route::post('/sync/push', [SyncController::class, 'push']);
    Route::get('/sync/pull', [SyncController::class, 'pull']);
    Route::post('/sync/retry-audit-logs', [SyncController::class, 'pushRetryAuditLogs']);
    Route::get('/sync/retry-audit-logs', [SyncController::class, 'listRetryAuditLogs']);
    Route::post('/sync/void-item-logs', [SyncController::class, 'pushVoidItemLogs']);
    Route::get('/sync/void-item-logs', [SyncController::class, 'listVoidItemLogs']);
    Route::get('/sync/log-overview', [SyncController::class, 'logOverview']);
});
