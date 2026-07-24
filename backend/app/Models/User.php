<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

#[Fillable(['name', 'email', 'password'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function relationshipsAsUserOne()
    {
        return $this->hasOne(Relationship::class, 'user_one_id');
    }

    public function relationshipsAsUserTwo()
    {
        return $this->hasOne(Relationship::class, 'user_two_id');
    }

    public function getRelationshipAttribute()
    {
        return $this->relationshipsAsUserOne ?? $this->relationshipsAsUserTwo;
    }

    public function partner()
    {
        $relationship = $this->relationship;
        if (!$relationship) {
            return null;
        }
        return $relationship->user_one_id === $this->id
            ? $relationship->userTwo
            : $relationship->userOne;
    }
}
