<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('ingredients', function (Blueprint $table) {
            $table->id();
            $table->string('ingredient_name');
            $table->string('unit', 20);
            $table->decimal('minimum_stock', 14, 3)->default(0);
            $table->decimal('cost_per_unit', 14, 4)->default(0);
            $table->foreignId('supplier_id')->nullable()->constrained('suppliers')->nullOnDelete();
            $table->timestamps();

            $table->index('ingredient_name');
        });
    }

    public function down()
    {
        Schema::dropIfExists('ingredients');
    }
};
