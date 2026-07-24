<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // User::factory(10)->create();

        $arun = User::create([
            'name' => 'Arun',
            'email' => 'arun@aura.com',
            'password' => Hash::make('password'),
        ]);

        $vaishali = User::create([
            'name' => 'Vaishali',
            'email' => 'vaishali@aura.com',
            'password' => Hash::make('password'),
        ]);

        \App\Models\Relationship::create([
            'user_one_id' => $arun->id,
            'user_two_id' => $vaishali->id,
            'anniversary_date' => \Carbon\Carbon::now('Asia/Kolkata')->subDays(420)->toDateString(),
        ]);
    }
}
