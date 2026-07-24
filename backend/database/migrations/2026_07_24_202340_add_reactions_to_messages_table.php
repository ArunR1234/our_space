<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->string('sender_reaction')->nullable()->after('is_read');
            $table->string('receiver_reaction')->nullable()->after('sender_reaction');
            $table->dropColumn('reaction');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->string('reaction')->nullable()->after('is_read');
            $table->dropColumn(['sender_reaction', 'receiver_reaction']);
        });
    }
};
