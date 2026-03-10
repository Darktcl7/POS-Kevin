<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('retry_audit_logs', function (Blueprint $table) {
            $table->id();
            $table->string('device_id', 120);
            $table->string('local_log_id', 120);
            $table->unsignedBigInteger('outlet_id')->nullable();
            $table->string('action_type', 40);
            $table->string('invoice_number', 120);
            $table->string('queue_id', 120)->nullable();
            $table->string('status', 30);
            $table->text('result_message');
            $table->string('performed_by', 190)->nullable();
            $table->timestamp('logged_at')->nullable();
            $table->timestamps();

            $table->unique(['device_id', 'local_log_id']);
            $table->index(['outlet_id', 'created_at']);
            $table->index(['status', 'created_at']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('retry_audit_logs');
    }
};
