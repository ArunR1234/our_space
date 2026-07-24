<?php

use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

Broadcast::channel('relationship.{relationshipId}', function ($user, $relationshipId) {
    $relationship = \App\Models\Relationship::find($relationshipId);
    if (!$relationship) {
        return false;
    }
    return (int) $user->id === (int) $relationship->user_one_id || (int) $user->id === (int) $relationship->user_two_id;
});
