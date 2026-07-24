<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\AuthController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\DatePlanController;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('/reset-password', [AuthController::class, 'resetPassword']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user-status', [AuthController::class, 'userStatus']);
    Route::post('/pair-partner', [AuthController::class, 'pairPartner']);
    Route::post('/cancel-pairing', [AuthController::class, 'cancelPairing']);
    
    Route::get('/dashboard-summary', [DashboardController::class, 'summary']);
    
    Route::get('/chat-messages', [ChatController::class, 'getMessages']);
    Route::post('/chat-messages', [ChatController::class, 'sendMessage']);
    Route::post('/chat-messages/{id}/read', [ChatController::class, 'markAsRead']);
    Route::post('/chat-messages/{id}/react', [ChatController::class, 'reactToMessage']);
    
    Route::get('/date-plans', [DatePlanController::class, 'getDatePlans']);
    Route::post('/date-plans', [DatePlanController::class, 'proposeDatePlan']);
    Route::post('/date-plans/{id}/respond', [DatePlanController::class, 'respondToDatePlan']);
});

Route::get('/db-status', function () {
    try {
        \Illuminate\Support\Facades\DB::connection()->getPdo();
        return response()->json([
            'status' => 'success',
            'message' => 'Successfully connected to the database: ' . \Illuminate\Support\Facades\DB::connection()->getDatabaseName()
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'status' => 'error',
            'message' => 'Could not connect to the database. Error: ' . $e->getMessage()
        ], 500);
    }
});
