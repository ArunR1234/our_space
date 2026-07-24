<?php

namespace App\Http\Controllers;

use App\Models\Message;
use App\Events\MessageSent;
use App\Events\MessageRead;
use App\Events\MessageReacted;
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

        $messages = Message::where('relationship_id', $relationship->id)
            ->orderBy('created_at', 'asc')
            ->get();

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
        ]);

        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $message = Message::create([
            'relationship_id' => $relationship->id,
            'sender_id' => $user->id,
            'content' => $request->content,
            'is_read' => false,
        ]);

        broadcast(new MessageSent($message))->toOthers();

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

        $message->update([
            'reaction' => $request->reaction, // can be null to remove reaction
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
}
