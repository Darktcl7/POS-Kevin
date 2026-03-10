<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('printers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('outlet_id')->constrained('outlets')->cascadeOnDelete();
            $table->string('printer_name');
            $table->string('connection_type', 20);
            $table->string('address', 120)->nullable();
            $table->string('port', 10)->nullable();
            $table->string('usb_vendor_id', 10)->nullable();
            $table->string('usb_product_id', 10)->nullable();
            $table->string('paper_size', 10)->default('58mm');
            $table->boolean('is_default')->default(false);
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['outlet_id', 'is_default']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('printers');
    }
};
