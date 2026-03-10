<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('void_item_logs', function (Blueprint $table) {
            $table->id();
            $table->string('device_id', 120);
            $table->string('local_log_id', 120);
            $table->unsignedBigInteger('outlet_id')->nullable();
            $table->string('product_name', 255);
            $table->unsignedInteger('quantity');
            $table->text('reason');
            $table->string('performed_by', 190)->nullable();
            $table->timestamp('logged_at')->nullable();
            $table->timestamps();

            $table->unique(['device_id', 'local_log_id']);
            $table->index(['outlet_id', 'created_at']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('void_item_logs');
    }
};
