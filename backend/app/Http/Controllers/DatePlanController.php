<?php

namespace App\Http\Controllers;

use App\Models\DatePlan;
use App\Events\DatePlanUpdated;
use App\Events\DatePlanDeleted;
use Illuminate\Http\Request;
use Carbon\Carbon;

class DatePlanController extends Controller
{
    public function getDatePlans(Request $request)
    {
        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $datePlans = DatePlan::where('relationship_id', $relationship->id)
            ->orderBy('date', 'asc')
            ->get();

        return response()->json($datePlans);
    }

    public function proposeDatePlan(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'date' => 'required|date',
            'location' => 'nullable|string|max:255',
        ]);

        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $datePlan = DatePlan::create([
            'relationship_id' => $relationship->id,
            'creator_id' => $user->id,
            'title' => $request->title,
            'date' => Carbon::parse($request->date),
            'location' => $request->location,
            'status' => 'pending',
        ]);

        broadcast(new DatePlanUpdated($datePlan))->toOthers();

        return response()->json($datePlan, 201);
    }

    public function respondToDatePlan(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:accepted,declined',
        ]);

        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $datePlan = DatePlan::where('id', $id)
            ->where('relationship_id', $relationship->id)
            ->firstOrFail();

        $datePlan->update([
            'status' => $request->status,
        ]);

        broadcast(new DatePlanUpdated($datePlan))->toOthers();

        return response()->json($datePlan);
    }

    public function updateDatePlan(Request $request, $id)
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'date' => 'required|date',
            'location' => 'nullable|string|max:255',
        ]);

        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $datePlan = DatePlan::where('id', $id)
            ->where('relationship_id', $relationship->id)
            ->where(function($query) use ($user) {
                $query->where('creator_id', $user->id)
                      ->orWhere('status', 'accepted');
            })
            ->firstOrFail();

        $datePlan->update([
            'creator_id' => $user->id,
            'title' => $request->title,
            'date' => Carbon::parse($request->date),
            'location' => $request->location,
            'status' => 'pending', // Reset status to pending so partner responds to the new details
        ]);

        broadcast(new DatePlanUpdated($datePlan))->toOthers();

        return response()->json($datePlan);
    }

    public function deleteDatePlan(Request $request, $id)
    {
        $user = $request->user();
        $relationship = $user->relationship;

        if (!$relationship) {
            return response()->json(['message' => 'No relationship setup.'], 403);
        }

        $datePlan = DatePlan::where('id', $id)
            ->where('relationship_id', $relationship->id)
            ->where(function($query) use ($user) {
                $query->where('creator_id', $user->id)
                      ->orWhere('status', 'accepted');
            })
            ->firstOrFail();

        $datePlanId = $datePlan->id;
        $datePlan->delete();

        broadcast(new DatePlanDeleted($datePlanId, $relationship->id))->toOthers();

        return response()->json(['message' => 'Date plan cancelled successfully.']);
    }
}
