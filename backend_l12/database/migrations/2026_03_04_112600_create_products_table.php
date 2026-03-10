<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained('categories')->restrictOnDelete();
            $table->string('product_name');
            $table->string('sku', 60)->unique();
            $table->decimal('selling_price', 14, 2)->default(0);
            $table->decimal('tax_percent', 5, 2)->default(0);
            $table->boolean('is_active')->default(true);
            $table->string('photo')->nullable();
            $table->timestamps();

            $table->index(['category_id', 'is_active']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('products');
    }
};
