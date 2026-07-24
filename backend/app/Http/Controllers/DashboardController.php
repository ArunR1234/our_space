<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Carbon\Carbon;
use App\Models\DatePlan;

class DashboardController extends Controller
{
    public function summary(Request $request)
    {
        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json([
                'paired' => false,
                'message' => 'No relationship setup yet.'
            ]);
        }

        // Days together
        $daysTogether = 0;
        if ($relationship->anniversary_date) {
            $anniversary = Carbon::parse($relationship->anniversary_date);
            $daysTogether = (int) $anniversary->diffInDays(Carbon::now());
        }

        // Next Date Plan
        $nextDate = DatePlan::where('relationship_id', $relationship->id)
            ->where('date', '>=', Carbon::now())
            ->whereIn('status', ['pending', 'accepted'])
            ->orderBy('date', 'asc')
            ->first();

        // Romantic quotes
        $quotes = [
            "Every moment with you is a new favorite memory. Can't wait for what's next.",
            "In your smile, I see something more beautiful than the stars.",
            "You are my today and all of my tomorrows.",
            "Loving you is the best thing that ever happened to me.",
            "My heart is and always will be yours.",
            "To the world you may be one person, but to me you are the world.",
            "I saw that you were perfect, and so I loved you. Then I saw that you were not perfect and I loved you even more."
        ];

        // Pick quote based on date to keep it consistent throughout the day
        $quoteIndex = (int) Carbon::now()->dayOfYear % count($quotes);
        $quote = $quotes[$quoteIndex];

        return response()->json([
            'paired' => true,
            'relationship_id' => $relationship->id,
            'days_together' => $daysTogether,
            'next_date' => $nextDate,
            'romantic_quote' => $quote,
            'partner' => $user->partner(),
        ]);
    }
}
