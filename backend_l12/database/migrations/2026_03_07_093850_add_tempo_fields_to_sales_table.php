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
        Schema::table('sales', function (Blueprint $table) {
            $table->string('customer_name')->nullable()->after('payment_method');
            $table->string('customer_phone')->nullable()->after('customer_name');
            $table->date('due_date')->nullable()->after('customer_phone');
            $table->string('payment_status', 20)->default('PAID')->after('due_date'); // PAID, UNPAID
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('sales', function (Blueprint $table) {
            $table->dropColumn(['customer_name', 'customer_phone', 'due_date', 'payment_status']);
        });
    }
};
