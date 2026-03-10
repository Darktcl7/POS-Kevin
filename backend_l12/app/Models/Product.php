<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Product extends Model
{
    protected $fillable = [
        'category_id',
        'product_name',
        'sku',
        'selling_price',
        'cost_price',
        'tax_percent',
        'is_active',
        'photo',
    ];

    protected $casts = [
        'selling_price' => 'decimal:2',
        'cost_price'    => 'decimal:2',
        'tax_percent'   => 'decimal:2',
        'is_active'     => 'boolean',
    ];

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function recipes(): HasMany
    {
        return $this->hasMany(Recipe::class);
    }

    public function getImageUrlAttribute(): ?string
    {
        if (empty($this->photo)) return null;
        return filter_var($this->photo, FILTER_VALIDATE_URL)
            ? $this->photo
            : url('storage/' . $this->photo);
    }
}
