<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('expenses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('outlet_id')->constrained('outlets')->cascadeOnDelete();
            $table->string('expense_name');
            $table->decimal('amount', 14, 2);
            $table->date('expense_date');
            $table->text('description')->nullable();
            $table->timestamps();

            $table->index(['outlet_id', 'expense_date']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('expenses');
    }
};
