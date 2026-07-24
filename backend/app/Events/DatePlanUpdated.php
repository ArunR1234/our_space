<?php

namespace App\Events;

use App\Models\DatePlan;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class DatePlanUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public DatePlan $datePlan;

    public function __construct(DatePlan $datePlan)
    {
        $this->datePlan = $datePlan;
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('relationship.' . $this->datePlan->relationship_id),
        ];
    }

    public function broadcastWith(): array
    {
        return [
            'id' => $this->datePlan->id,
            'relationship_id' => $this->datePlan->relationship_id,
            'creator_id' => $this->datePlan->creator_id,
            'title' => $this->datePlan->title,
            'date' => $this->datePlan->date->toIso8601String(),
            'location' => $this->datePlan->location,
            'status' => $this->datePlan->status,
        ];
    }
}
