<?php

namespace App\Events;

use App\Models\User;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PartnerConnected implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public int $relationshipId;
    public User $partner;

    public function __construct(int $relationshipId, User $partner)
    {
        $this->relationshipId = $relationshipId;
        $this->partner = $partner;
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
            'relationship_id' => $this->relationshipId,
            'partner' => [
                'id' => $this->partner->id,
                'name' => $this->partner->name,
                'email' => $this->partner->email,
            ],
            'message' => 'Partner has connected!',
        ];
    }
}
