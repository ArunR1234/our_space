<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class AnniversaryUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public int $relationshipId;
    public ?string $anniversaryDate;

    /**
     * Create a new event instance.
     */
    public function __construct(int $relationshipId, ?string $anniversaryDate)
    {
        $this->relationshipId = $relationshipId;
        $this->anniversaryDate = $anniversaryDate;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('relationship.' . $this->relationshipId),
        ];
    }

    /**
     * Get the data to broadcast.
     *
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'relationship_id' => $this->relationshipId,
            'anniversary_date' => $this->anniversaryDate,
        ];
    }
}
