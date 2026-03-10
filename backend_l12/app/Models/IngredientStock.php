<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class IngredientStock extends Model
{
    protected $fillable = [
        'warehouse_id',
        'ingredient_id',
        'on_hand_qty',
        'last_movement_at',
    ];

    protected $casts = [
        'on_hand_qty'      => 'decimal:3',
        'last_movement_at' => 'datetime',
    ];

    public function warehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class);
    }

    public function ingredient(): BelongsTo
    {
        return $this->belongsTo(Ingredient::class);
    }

    public function isLow(): bool
    {
        return (float)$this->on_hand_qty <= (float)$this->ingredient->minimum_stock;
    }
}
