<?php

namespace App\Services;

use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmService
{
    public function sendNotification(string $deviceToken, string $title, string $body, array $data = [])
    {
        $keyPath = storage_path('app/firebase-service-account.json');
        if (!file_exists($keyPath)) {
            Log::error('FCM: Cannot send push notification. firebase-service-account.json is missing.');
            return false;
        }

        try {
            $authConfig = json_decode(file_get_contents($keyPath), true);
            $projectId = $authConfig['project_id'] ?? null;
            $privateKey = $authConfig['private_key'] ?? null;
            $clientEmail = $authConfig['client_email'] ?? null;

            if (!$projectId || !$privateKey || !$clientEmail) {
                Log::error('FCM: Invalid service account details.');
                return false;
            }

            // Generate JWT assertion manually to bypass Google Client SSL validation issues locally
            $now = time();
            $jwtPayload = [
                'iss' => $clientEmail,
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ];

            $jwt = JWT::encode($jwtPayload, $privateKey, 'RS256');

            // Request access token with verification disabled
            $tokenResponse = Http::withoutVerifying()->asForm()->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]);

            if (!$tokenResponse->successful()) {
                Log::error('FCM OAuth Token Request Failed: ' . $tokenResponse->body());
                return false;
            }

            $tokenData = $tokenResponse->json();
            $tokenString = $tokenData['access_token'] ?? null;

            if (!$tokenString) {
                Log::error('FCM: Access token empty in response.');
                return false;
            }

            // Send push notification using FCM HTTP v1 endpoint
            $payload = [
                'message' => [
                    'token' => $deviceToken,
                    'notification' => [
                        'title' => $title,
                        'body' => $body,
                    ],
                    'data' => array_map('strval', $data),
                    'android' => [
                        'priority' => 'high',
                        'notification' => [
                            'sound' => 'default',
                        ],
                    ],
                    'apns' => [
                        'payload' => [
                            'aps' => [
                                'sound' => 'default',
                                'badge' => 1,
                            ],
                        ],
                    ],
                ],
            ];

            $response = Http::withoutVerifying()->withHeaders([
                'Authorization' => 'Bearer ' . $tokenString,
                'Content-Type' => 'application/json',
            ])->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", $payload);

            if ($response->successful()) {
                return true;
            } else {
                Log::error('FCM Send Error: ' . $response->body());
                return false;
            }

        } catch (\Exception $e) {
            Log::error('FCM Exception: ' . $e->getMessage());
            return false;
        }
    }
}
