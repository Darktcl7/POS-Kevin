<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PurchaseController extends Controller
{
    public function receive(Request $request, int $purchaseId)
    {
        $data = $request->validate([
            'warehouse_id' => ['nullable', 'integer', 'exists:warehouses,id'],
        ]);

        $user = $request->user();

        DB::transaction(function () use ($purchaseId, $data, $user) {
            $purchase = DB::table('purchases')->lockForUpdate()->where('id', $purchaseId)->first();

            if (! $purchase) {
                throw ValidationException::withMessages(['purchase_id' => ['Purchase tidak ditemukan.']]);
            }

            if ($purchase->status === 'RECEIVED') {
                throw ValidationException::withMessages(['purchase_id' => ['Purchase sudah diterima sebelumnya.']]);
            }

            $warehouseId = $data['warehouse_id'] ?? $this->resolveWarehouseId((int) $purchase->outlet_id);
            $details = DB::table('purchase_details')->where('purchase_id', $purchaseId)->get();
            $now = Carbon::now();

            if ($details->isEmpty()) {
                throw ValidationException::withMessages(['purchase_id' => ['Purchase details kosong.']]);
            }

            foreach ($details as $detail) {
                $stock = DB::table('ingredient_stocks')
                    ->where('warehouse_id', $warehouseId)
                    ->where('ingredient_id', $detail->ingredient_id)
                    ->lockForUpdate()
                    ->first();

                if ($stock) {
                    DB::table('ingredient_stocks')->where('id', $stock->id)->update([
                        'on_hand_qty' => (float) $stock->on_hand_qty + (float) $detail->quantity,
                        'last_movement_at' => $now,
                        'updated_at' => $now,
                    ]);
                } else {
                    DB::table('ingredient_stocks')->insert([
                        'warehouse_id' => $warehouseId,
                        'ingredient_id' => $detail->ingredient_id,
                        'on_hand_qty' => $detail->quantity,
                        'last_movement_at' => $now,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }

                DB::table('stock_movements')->insert([
                    'ingredient_id' => $detail->ingredient_id,
                    'warehouse_id' => $warehouseId,
                    'type' => 'IN',
                    'quantity' => $detail->quantity,
                    'reference_id' => $purchaseId,
                    'reference_type' => 'PURCHASE',
                    'notes' => 'Auto stock in from purchase receive',
                    'created_by' => $user->id,
                    'movement_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            DB::table('purchases')->where('id', $purchaseId)->update([
                'status' => 'RECEIVED',
                'received_at' => $now,
                'updated_at' => $now,
            ]);
        });

        return response()->json(['message' => 'Purchase received successfully.']);
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
