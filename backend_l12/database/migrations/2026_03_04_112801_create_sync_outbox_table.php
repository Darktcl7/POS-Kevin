<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('sync_outbox', function (Blueprint $table) {
            $table->id();
            $table->string('device_id', 120);
            $table->string('entity_type', 40);
            $table->string('operation', 20);
            $table->string('entity_local_id', 120)->nullable();
            $table->unsignedBigInteger('entity_server_id')->nullable();
            $table->json('payload');
            $table->string('status', 20)->default('PENDING');
            $table->unsignedInteger('retry_count')->default(0);
            $table->timestamp('last_try_at')->nullable();
            $table->timestamp('synced_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'created_at']);
            $table->index(['device_id', 'entity_type']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('sync_outbox');
    }
};
