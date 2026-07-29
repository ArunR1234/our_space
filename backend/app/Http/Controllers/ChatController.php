<?php

namespace App\Http\Controllers;

use App\Models\Message;
use App\Events\MessageSent;
use App\Events\MessageRead;
use App\Events\MessageReacted;
use App\Events\MessageUpdated;
use App\Events\MessageDeleted;
use Illuminate\Http\Request;

class ChatController extends Controller
{
    public function getMessages(Request $request)
    {
        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $messagesQuery = Message::where('relationship_id', $relationship->id)
            ->with('replyTo');

        if ($user->chat_cleared_at) {
            $messagesQuery->where('created_at', '>', $user->chat_cleared_at);
        }

        $messages = $messagesQuery->orderBy('created_at', 'asc')->get();

        // Mark incoming messages as read
        $unreadMessages = Message::where('relationship_id', $relationship->id)
            ->where('sender_id', '!=', $user->id)
            ->where('is_read', false)
            ->get();

        foreach ($unreadMessages as $msg) {
            $msg->update(['is_read' => true]);
            broadcast(new MessageRead($msg))->toOthers();
        }

        return response()->json($messages);
    }

    public function sendMessage(Request $request)
    {
        $request->validate([
            'content' => 'required|string',
            'reply_to_id' => 'nullable|exists:messages,id',
        ]);

        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $message = Message::create([
            'relationship_id' => $relationship->id,
            'sender_id' => $user->id,
            'reply_to_id' => $request->reply_to_id,
            'content' => $request->content,
            'is_read' => false,
        ]);

        $message->load('replyTo');

        broadcast(new MessageSent($message))->toOthers();

        // Send push notification to partner
        $partner = $user->partner();
        if ($partner && $partner->fcm_token) {
            try {
                $fcmService = resolve(\App\Services\FcmService::class);
                
                // Hide message details if the partner has show_previews disabled
                $notificationTitle = ($partner->show_previews !== false) ? $user->name : 'Our Space';
                $notificationBody = ($partner->show_previews !== false) ? $message->content : 'You have a new message';

                $fcmService->sendNotification(
                    $partner->fcm_token,
                    $notificationTitle,
                    $notificationBody,
                    [
                        'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                        'type' => 'chat',
                        'relationship_id' => (string) $relationship->id,
                    ]
                );
            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Log::error('FCM Send Exception: ' . $e->getMessage());
            }
        }

        return response()->json($message, 201);
    }

    public function reactToMessage(Request $request, $id)
    {
        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $message = Message::where('id', $id)
            ->where('relationship_id', $relationship->id)
            ->firstOrFail();

        $isSender = $message->sender_id === $user->id;

        $message->update([
            ($isSender ? 'sender_reaction' : 'receiver_reaction') => $request->reaction,
        ]);

        broadcast(new MessageReacted($message))->toOthers();

        return response()->json($message);
    }

    public function markAsRead(Request $request, $id)
    {
        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $message = Message::where('id', $id)
            ->where('relationship_id', $relationship->id)
            ->where('sender_id', '!=', $user->id)
            ->firstOrFail();

        if (!$message->is_read) {
            $message->update(['is_read' => true]);
            broadcast(new MessageRead($message))->toOthers();
        }

        return response()->json($message);
    }

    public function updateMessage(Request $request, $id)
    {
        $request->validate([
            'content' => 'required|string',
        ]);

        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $message = Message::where('id', $id)
            ->where('relationship_id', $relationship->id)
            ->where('sender_id', $user->id)
            ->firstOrFail();

        $message->update([
            'content' => $request->content,
        ]);

        broadcast(new MessageUpdated($message))->toOthers();

        return response()->json($message);
    }

    public function deleteMessage(Request $request, $id)
    {
        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $message = Message::where('id', $id)
            ->where('relationship_id', $relationship->id)
            ->where('sender_id', $user->id)
            ->firstOrFail();

        $messageId = $message->id;
        $message->delete();

        broadcast(new MessageDeleted($messageId, $relationship->id))->toOthers();

        return response()->json(['message' => 'Message unsent successfully.']);
    }

    public function clearHistory(Request $request)
    {
        $user = $request->user();
        $user->update(['chat_cleared_at' => now()]);
        return response()->json(['message' => 'Chat history cleared.']);
    }
}
