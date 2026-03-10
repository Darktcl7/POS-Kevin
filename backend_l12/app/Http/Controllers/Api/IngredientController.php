<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class IngredientController extends Controller
{
    public function index()
    {
        $ingredients = DB::table('ingredients')
            ->leftJoin('suppliers', 'suppliers.id', '=', 'ingredients.supplier_id')
            ->select(
                'ingredients.id',
                'ingredients.ingredient_name',
                'ingredients.unit',
                'ingredients.cost_per_unit',
                'ingredients.minimum_stock',
                'suppliers.supplier_name'
            )
            ->orderBy('ingredients.ingredient_name')
            ->get();

        foreach ($ingredients as $ing) {
            $ing->stocks = DB::table('ingredient_stocks')
                ->join('warehouses', 'warehouses.id', '=', 'ingredient_stocks.warehouse_id')
                ->where('ingredient_stocks.ingredient_id', $ing->id)
                ->select('ingredient_stocks.on_hand_qty', 'warehouses.warehouse_name')
                ->get();
            $ing->total_stock = $ing->stocks->sum('on_hand_qty');
        }

        $warehouses = DB::table('warehouses')->select('id', 'warehouse_name')->get();
        $suppliers = DB::table('suppliers')->select('id', 'supplier_name')->get();

        return response()->json([
            'ingredients' => $ingredients,
            'warehouses' => $warehouses,
            'suppliers' => $suppliers,
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'ingredient_name' => 'required|string|max:255',
            'unit' => 'required|string|max:20',
            'cost_per_unit' => 'required|numeric|min:0',
            'minimum_stock' => 'required|numeric|min:0',
            'supplier_id' => 'nullable|exists:suppliers,id',
        ]);

        $id = DB::table('ingredients')->insertGetId(array_merge($data, [
            'created_at' => now(),
            'updated_at' => now(),
        ]));

        $warehouse = DB::table('warehouses')->where('is_main', true)->first() 
            ?? DB::table('warehouses')->first();

        if ($warehouse) {
            DB::table('ingredient_stocks')->insert([
                'warehouse_id' => $warehouse->id,
                'ingredient_id' => $id,
                'on_hand_qty' => 0,
                'last_movement_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        return response()->json(['message' => 'Bahan baku berhasil ditambahkan', 'id' => $id]);
    }

    public function updateStock(Request $request, $id)
    {
        $request->validate([
            'warehouse_id' => 'required|exists:warehouses,id',
            'added_qty' => 'required|numeric|min:0',
        ]);

        $stock = DB::table('ingredient_stocks')
            ->where('warehouse_id', $request->warehouse_id)
            ->where('ingredient_id', $id)
            ->first();

        if ($stock) {
            DB::table('ingredient_stocks')
                ->where('id', $stock->id)
                ->update([
                    'on_hand_qty' => $stock->on_hand_qty + $request->added_qty,
                    'last_movement_at' => now(),
                    'updated_at' => now(),
                ]);
        } else {
            DB::table('ingredient_stocks')->insert([
                'warehouse_id' => $request->warehouse_id,
                'ingredient_id' => $id,
                'on_hand_qty' => $request->added_qty,
                'last_movement_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        return response()->json(['message' => 'Stok bahan baku diperbarui']);
    }

    public function destroy($id)
    {
        DB::table('ingredients')->where('id', $id)->delete();
        return response()->json(['message' => 'Bahan baku berhasil dihapus']);
    }
}
