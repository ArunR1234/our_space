<?php

namespace App\Events;

use App\Models\Message;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Message $message;

    public function __construct(Message $message)
    {
        $this->message = $message;
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('relationship.' . $this->message->relationship_id),
        ];
    }

    public function broadcastWith(): array
    {
        return [
            'id' => $this->message->id,
            'relationship_id' => $this->message->relationship_id,
            'sender_id' => $this->message->sender_id,
            'reply_to_id' => $this->message->reply_to_id,
            'reply_to' => $this->message->replyTo ? [
                'id' => $this->message->replyTo->id,
                'sender_id' => $this->message->replyTo->sender_id,
                'content' => $this->message->replyTo->content,
            ] : null,
            'content' => $this->message->content,
            'is_read' => $this->message->is_read,
            'reaction' => $this->message->reaction,
            'created_at' => $this->message->created_at->toIso8601String(),
            'updated_at' => $this->message->updated_at ? $this->message->updated_at->toIso8601String() : $this->message->created_at->toIso8601String(),
        ];
    }
}
