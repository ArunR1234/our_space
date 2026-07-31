<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\AuthController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\DatePlanController;

Route::middleware('throttle:6,1')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/signup/verify-otp', [AuthController::class, 'verifySignupOtp']);
});

Route::middleware('throttle:3,1')->group(function () {
    Route::post('/signup/send-otp', [AuthController::class, 'sendSignupOtp']);
    Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
});

Route::middleware('throttle:5,1')->group(function () {
    Route::post('/reset-password', [AuthController::class, 'resetPassword']);
});

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user-status', [AuthController::class, 'userStatus']);
    Route::post('/pair-partner', [AuthController::class, 'pairPartner']);
    Route::post('/cancel-pairing', [AuthController::class, 'cancelPairing']);
    Route::post('/user/update', [AuthController::class, 'updateProfile']);
    Route::post('/user/fcm-token', [AuthController::class, 'updateFcmToken']);
    Route::post('/user/preferences', [AuthController::class, 'updatePreferences']);
    
    Route::get('/user/devices', [AuthController::class, 'getDevices']);
    Route::delete('/user/devices/{id}', [AuthController::class, 'logoutDevice']);
    Route::post('/user/devices/logout-others', [AuthController::class, 'logoutOtherDevices']);
    
    Route::get('/dashboard-summary', [DashboardController::class, 'summary']);
    Route::post('/relationship/anniversary', [DashboardController::class, 'updateAnniversary']);
    
    Route::get('/chat-messages', [ChatController::class, 'getMessages']);
    Route::post('/chat-messages', [ChatController::class, 'sendMessage']);
    Route::post('/chat-messages/clear', [ChatController::class, 'clearHistory']);
    Route::put('/chat-messages/{id}', [ChatController::class, 'updateMessage']);
    Route::delete('/chat-messages/{id}', [ChatController::class, 'deleteMessage']);
    Route::post('/chat-messages/{id}/read', [ChatController::class, 'markAsRead']);
    Route::post('/chat-messages/{id}/react', [ChatController::class, 'reactToMessage']);
    
    Route::get('/date-plans', [DatePlanController::class, 'getDatePlans']);
    Route::post('/date-plans', [DatePlanController::class, 'proposeDatePlan']);
    Route::post('/date-plans/{id}/respond', [DatePlanController::class, 'respondToDatePlan']);
    Route::put('/date-plans/{id}', [DatePlanController::class, 'updateDatePlan']);
    Route::delete('/date-plans/{id}', [DatePlanController::class, 'deleteDatePlan']);
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
