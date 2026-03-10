<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SaleController extends Controller
{
    public function history(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['required', 'integer', 'exists:outlets,id'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:100'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
        ]);

        $limit = (int) ($data['limit'] ?? 30);
        $from = isset($data['from']) ? Carbon::parse($data['from'])->startOfDay() : null;
        $to = isset($data['to']) ? Carbon::parse($data['to'])->endOfDay() : null;

        $salesQuery = DB::table('sales')
            ->where('outlet_id', $data['outlet_id'])
            ->orderByDesc('id');

        if ($from && $to) {
            $salesQuery->whereBetween('created_at', [$from, $to]);
        } elseif ($from) {
            $salesQuery->where('created_at', '>=', $from);
        } elseif ($to) {
            $salesQuery->where('created_at', '<=', $to);
        }

        $sales = $salesQuery
            ->limit($limit)
            ->get([
                'id',
                'invoice_number',
                'outlet_id',
                'total_amount',
                'sync_status',
                'payment_method',
                'order_type',
                'sold_at',
                'created_at',
                'customer_name',
                'customer_phone',
                'due_date',
                'payment_status',
            ]);

        $saleIds = $sales->pluck('id')->all();
        $detailRows = collect();

        if (! empty($saleIds)) {
            $detailRows = DB::table('sale_details as sd')
                ->join('products as p', 'p.id', '=', 'sd.product_id')
                ->whereIn('sd.sale_id', $saleIds)
                ->orderBy('sd.id')
                ->get([
                    'sd.sale_id',
                    'p.product_name',
                    'sd.quantity',
                    'sd.price',
                    'sd.subtotal',
                ])
                ->groupBy('sale_id');
        }

        $items = $sales->map(function ($sale) use ($detailRows) {
            $details = ($detailRows[$sale->id] ?? collect())->map(function ($row) {
                return [
                    'product_name' => $row->product_name,
                    'quantity' => (float) $row->quantity,
                    'price' => (float) $row->price,
                    'subtotal' => (float) $row->subtotal,
                ];
            })->values();

            return [
                'id' => (int) $sale->id,
                'invoice_number' => $sale->invoice_number,
                'outlet_id' => (int) $sale->outlet_id,
                'total_amount' => (float) $sale->total_amount,
                'sync_status' => $sale->sync_status,
                'payment_method' => $sale->payment_method,
                'order_type' => $sale->order_type,
                'sold_at' => $sale->sold_at,
                'created_at' => $sale->created_at,
                'customer_name' => $sale->customer_name,
                'customer_phone' => $sale->customer_phone,
                'due_date' => $sale->due_date,
                'payment_status' => $sale->payment_status,
                'details' => $details,
            ];
        })->values();

        return response()->json([
            'outlet_id' => (int) $data['outlet_id'],
            'from' => $from?->toDateString(),
            'to' => $to?->toDateString(),
            'items' => $items,
        ]);
    }

    public function tempo(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['required', 'integer', 'exists:outlets,id'],
        ]);

        $sales = DB::table('sales')
            ->where('outlet_id', $data['outlet_id'])
            ->where('payment_method', 'TEMPO')
            ->where('payment_status', 'UNPAID')
            ->orderBy('due_date', 'asc')
            ->get([
                'id',
                'invoice_number',
                'total_amount',
                'sold_at',
                'customer_name',
                'customer_phone',
                'due_date',
                'payment_status',
            ]);

        return response()->json($sales);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'invoice_number' => ['required', 'string', 'max:80', 'unique:sales,invoice_number'],
            'outlet_id' => ['required', 'integer', 'exists:outlets,id'],
            'warehouse_id' => ['nullable', 'integer', 'exists:warehouses,id'],
            'payment_method' => ['required', 'string', 'max:30'],
            'order_type' => ['required', 'string', 'max:20'],
            'sold_at' => ['nullable', 'date'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity' => ['required', 'numeric', 'gt:0'],
            'items.*.price' => ['required', 'numeric', 'gte:0'],
            'customer_name' => ['nullable', 'string', 'max:255'],
            'customer_phone' => ['nullable', 'string', 'max:50'],
            'due_date' => ['nullable', 'date'],
        ]);

        $user = $request->user();

        $result = DB::transaction(function () use ($data, $user) {
            $warehouseId = $data['warehouse_id'] ?? $this->resolveWarehouseId($data['outlet_id']);
            $now = Carbon::now();

            $totalAmount = collect($data['items'])
                ->sum(fn ($item) => (float) $item['quantity'] * (float) $item['price']);

            $isTempo = strtoupper($data['payment_method']) === 'TEMPO';

            $saleId = DB::table('sales')->insertGetId([
                'invoice_number' => $data['invoice_number'],
                'outlet_id' => $data['outlet_id'],
                'user_id' => $user->id,
                'total_amount' => $totalAmount,
                'payment_method' => $data['payment_method'],
                'order_type' => $data['order_type'],
                'sync_status' => 'SYNCED',
                'sold_at' => $data['sold_at'] ?? $now,
                'customer_name' => $data['customer_name'] ?? null,
                'customer_phone' => $data['customer_phone'] ?? null,
                'due_date' => $data['due_date'] ?? null,
                'payment_status' => $isTempo ? 'UNPAID' : 'PAID',
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $saleDetails = [];
            $productQty = [];

            foreach ($data['items'] as $item) {
                $subtotal = (float) $item['quantity'] * (float) $item['price'];

                $saleDetails[] = [
                    'sale_id' => $saleId,
                    'product_id' => $item['product_id'],
                    'quantity' => $item['quantity'],
                    'price' => $item['price'],
                    'subtotal' => $subtotal,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];

                $productQty[$item['product_id']] = ($productQty[$item['product_id']] ?? 0) + (float) $item['quantity'];
            }

            DB::table('sale_details')->insert($saleDetails);

            $recipes = DB::table('recipes')
                ->whereIn('product_id', array_keys($productQty))
                ->get(['product_id', 'ingredient_id', 'quantity_used']);

            $requiredIngredients = [];
            foreach ($recipes as $recipe) {
                $needed = $productQty[$recipe->product_id] * (float) $recipe->quantity_used;
                $requiredIngredients[$recipe->ingredient_id] = ($requiredIngredients[$recipe->ingredient_id] ?? 0) + $needed;
            }

            foreach ($requiredIngredients as $ingredientId => $neededQty) {
                $stock = DB::table('ingredient_stocks')
                    ->where('warehouse_id', $warehouseId)
                    ->where('ingredient_id', $ingredientId)
                    ->lockForUpdate()
                    ->first();

                $onHand = $stock ? (float) $stock->on_hand_qty : 0;
                if ($onHand < $neededQty) {
                    throw ValidationException::withMessages([
                        'stock' => ["Stok bahan #{$ingredientId} tidak cukup. Tersedia {$onHand}, butuh {$neededQty}."],
                    ]);
                }

                DB::table('ingredient_stocks')
                    ->where('id', $stock->id)
                    ->update([
                        'on_hand_qty' => $onHand - $neededQty,
                        'last_movement_at' => $now,
                        'updated_at' => $now,
                    ]);

                DB::table('stock_movements')->insert([
                    'ingredient_id' => $ingredientId,
                    'warehouse_id' => $warehouseId,
                    'type' => 'SALE',
                    'quantity' => $neededQty,
                    'reference_id' => $saleId,
                    'reference_type' => 'SALE',
                    'notes' => 'Auto deduct from sale',
                    'created_by' => $user->id,
                    'movement_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            return DB::table('sales')->where('id', $saleId)->first();
        });

        return response()->json($result, 201);
    }

    private function resolveWarehouseId(int $outletId): int
    {
        $warehouse = DB::table('warehouses')
            ->where('outlet_id', $outletId)
            ->orderByDesc('is_main')
            ->orderBy('id')
            ->first();

        if (! $warehouse) {
            throw ValidationException::withMessages([
                'warehouse_id' => ['Gudang untuk outlet belum tersedia.'],
            ]);
        }

        return (int) $warehouse->id;
    }
}
