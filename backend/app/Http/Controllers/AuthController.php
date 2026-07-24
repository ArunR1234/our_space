<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Relationship;
use App\Mail\PartnerInvitationMail;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Mail;
use Carbon\Carbon;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:6',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
        ]);

        // Auto-pair if someone invited this email
        $relationship = Relationship::where('pending_partner_email', $user->email)->first();
        if ($relationship) {
            $relationship->update([
                'user_two_id' => $user->id,
                'pending_partner_email' => null,
            ]);
            event(new \App\Events\PartnerConnected($relationship->id, $user));
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'access_token' => $token,
            'token_type' => 'Bearer',
            'user' => $user,
            'relationship' => $user->relationship,
            'partner' => $user->partner(),
        ]);
    }

    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|string|email',
            'password' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'message' => 'Invalid login credentials'
            ], 401);
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'access_token' => $token,
            'token_type' => 'Bearer',
            'user' => $user,
            'relationship' => $user->relationship,
            'partner' => $user->partner(),
        ]);
    }

    public function userStatus(Request $request)
    {
        $user = $request->user();
        return response()->json([
            'user' => $user,
            'relationship' => $user->relationship,
            'partner' => $user->partner(),
        ]);
    }

    public function pairPartner(Request $request)
    {
        $request->validate([
            'partner_email' => 'required|email'
        ]);

        $user = $request->user();
        $partnerEmail = trim($request->partner_email);

        if (strtolower($user->email) === strtolower($partnerEmail)) {
            return response()->json(['message' => 'You cannot pair with yourself.'], 422);
        }

        // Check if user already has a relationship
        if ($user->relationship) {
            $existing = $user->relationship;
            if ($existing->user_two_id !== null) {
                return response()->json(['message' => 'You are already in a relationship.'], 422);
            }
            // Delete the pending relationship to allow re-pairing with a different email
            $existing->delete();
            // Refresh relationship relation on user model
            $user->unsetRelation('relationship');
        }

        // Check if partner already has a relationship
        $partner = User::where('email', $partnerEmail)->first();
        if ($partner && $partner->relationship) {
            return response()->json(['message' => 'This partner is already paired with someone else.'], 422);
        }

        // Default anniversary: 420 days ago
        $anniversaryDate = Carbon::now('Asia/Kolkata')->subDays(420)->toDateString();

        if ($partner) {
            $relationship = Relationship::create([
                'user_one_id' => $user->id,
                'user_two_id' => $partner->id,
                'anniversary_date' => $anniversaryDate,
            ]);
            event(new \App\Events\PartnerConnected($relationship->id, $user));
        } else {
            $relationship = Relationship::create([
                'user_one_id' => $user->id,
                'pending_partner_email' => $partnerEmail,
                'anniversary_date' => $anniversaryDate,
            ]);

            // Send partner invitation mail
            try {
                Mail::to($partnerEmail)->send(new PartnerInvitationMail($user->name));
            } catch (\Exception $e) {
                logger()->error('Failed to send partner invitation mail: ' . $e->getMessage());
            }
        }

        return response()->json([
            'relationship' => $relationship,
            'partner' => $partner,
            'message' => $partner ? 'Successfully connected with partner!' : 'Connection request sent! Waiting for partner to sign up.'
        ]);
    }

    public function forgotPassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|string|email|exists:users,email',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'The selected email is invalid or does not exist.'], 422);
        }

        $email = $request->email;
        $otp = (string) mt_rand(100000, 999999);

        \Illuminate\Support\Facades\DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $email],
            [
                'token' => Hash::make($otp),
                'created_at' => Carbon::now()
            ]
        );

        logger()->info("Password reset OTP for {$email} is: {$otp}");

        return response()->json([
            'message' => 'Reset code sent successfully.',
            'debug_otp' => config('app.debug') ? $otp : null
        ]);
    }

    public function resetPassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|string|email|exists:users,email',
            'otp' => 'required|string|size:6',
            'password' => 'required|string|min:6|confirmed',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => $validator->errors()->first()], 422);
        }

        $resetRecord = \Illuminate\Support\Facades\DB::table('password_reset_tokens')
            ->where('email', $request->email)
            ->first();

        if (!$resetRecord) {
            return response()->json(['message' => 'No active password reset request found.'], 422);
        }

        if (Carbon::parse($resetRecord->created_at)->addMinutes(15)->isPast()) {
            \Illuminate\Support\Facades\DB::table('password_reset_tokens')->where('email', $request->email)->delete();
            return response()->json(['message' => 'The reset code has expired. Please request a new one.'], 422);
        }

        if (!Hash::check($request->otp, $resetRecord->token)) {
            return response()->json(['message' => 'Invalid reset code.'], 422);
        }

        $user = User::where('email', $request->email)->first();
        $user->update([
            'password' => Hash::make($request->password)
        ]);

        \Illuminate\Support\Facades\DB::table('password_reset_tokens')->where('email', $request->email)->delete();

        return response()->json([
            'message' => 'Password reset successfully. You can now login.'
        ]);
    }

    public function cancelPairing(Request $request)
    {
        $user = $request->user();
        if ($user->relationship) {
            $existing = $user->relationship;
            if ($existing->user_two_id === null) {
                $existing->delete();
                return response()->json(['message' => 'Pairing request cancelled successfully.']);
            }
        }
        return response()->json(['message' => 'No pending pairing request found.'], 422);
    }
}
