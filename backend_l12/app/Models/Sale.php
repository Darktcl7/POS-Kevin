<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Sale extends Model
{
    protected $fillable = [
        'invoice_number',
        'outlet_id',
        'warehouse_id',
        'user_id',
        'payment_method',
        'order_type',
        'subtotal',
        'tax_amount',
        'total_amount',
        'customer_name',
        'customer_phone',
        'due_date',
        'payment_status',
    ];

    protected $casts = [
        'subtotal'     => 'decimal:2',
        'tax_amount'   => 'decimal:2',
        'total_amount' => 'decimal:2',
        'due_date'     => 'date',
    ];

    public function outlet(): BelongsTo
    {
        return $this->belongsTo(Outlet::class);
    }

    public function details(): HasMany
    {
        return $this->hasMany(SaleDetail::class);
    }

    public function isTempo(): bool
    {
        return strtoupper($this->payment_method) === 'TEMPO';
    }

    public function isOverdue(): bool
    {
        return $this->isTempo()
            && $this->payment_status !== 'PAID'
            && $this->due_date
            && $this->due_date->isPast();
    }
}
