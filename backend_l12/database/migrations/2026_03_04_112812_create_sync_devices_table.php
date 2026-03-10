<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('sync_devices', function (Blueprint $table) {
            $table->id();
            $table->string('device_id', 120)->unique();
            $table->string('device_name')->nullable();
            $table->string('platform', 20)->default('ANDROID');
            $table->foreignId('outlet_id')->constrained('outlets')->cascadeOnDelete();
            $table->foreignId('last_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('last_sync_at')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['outlet_id', 'is_active']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('sync_devices');
    }
};
