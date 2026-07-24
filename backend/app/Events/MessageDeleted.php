<?php

namespace App\Events;

use App\Models\Message;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageDeleted implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public int $messageId;
    public int $relationshipId;

    public function __construct(int $messageId, int $relationshipId)
    {
        $this->messageId = $messageId;
        $this->relationshipId = $relationshipId;
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('relationship.' . $this->relationshipId),
        ];
    }

    public function broadcastWith(): array
    {
        return [
            'id' => $this->messageId,
            'relationship_id' => $this->relationshipId,
        ];
    }
}
