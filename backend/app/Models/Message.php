<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['relationship_id', 'sender_id', 'reply_to_id', 'content', 'is_read', 'sender_reaction', 'receiver_reaction'])]
class Message extends Model
{
    protected function casts(): array
    {
        return [
            'is_read' => 'boolean',
        ];
    }

    public function relationship(): BelongsTo
    {
        return $this->belongsTo(Relationship::class);
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function replyTo(): BelongsTo
    {
        return $this->belongsTo(Message::class, 'reply_to_id');
    }
}
