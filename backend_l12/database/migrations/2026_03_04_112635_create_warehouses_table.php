<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('warehouses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('outlet_id')->constrained('outlets')->cascadeOnDelete();
            $table->string('warehouse_name');
            $table->boolean('is_main')->default(false);
            $table->timestamps();

            $table->unique(['outlet_id', 'warehouse_name']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('warehouses');
    }
};
