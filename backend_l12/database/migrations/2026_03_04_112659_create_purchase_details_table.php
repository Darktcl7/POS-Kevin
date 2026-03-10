<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('purchase_details', function (Blueprint $table) {
            $table->id();
            $table->foreignId('purchase_id')->constrained('purchases')->cascadeOnDelete();
            $table->foreignId('ingredient_id')->constrained('ingredients')->restrictOnDelete();
            $table->decimal('quantity', 14, 3);
            $table->decimal('price', 14, 4);
            $table->decimal('subtotal', 14, 2);
            $table->timestamps();

            $table->index(['purchase_id', 'ingredient_id']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('purchase_details');
    }
};
