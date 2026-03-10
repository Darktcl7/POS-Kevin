<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('sales', function (Blueprint $table) {
            $table->id();
            $table->string('invoice_number', 80)->unique();
            $table->foreignId('outlet_id')->constrained('outlets')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->restrictOnDelete();
            $table->decimal('total_amount', 14, 2)->default(0);
            $table->string('payment_method', 30);
            $table->string('order_type', 20)->default('DINE_IN');
            $table->string('sync_status', 20)->default('SYNCED');
            $table->timestamp('sold_at')->nullable();
            $table->timestamps();

            $table->index(['outlet_id', 'created_at']);
            $table->index(['sync_status', 'created_at']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('sales');
    }
};
