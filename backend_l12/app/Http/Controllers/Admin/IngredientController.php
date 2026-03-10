<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Ingredient;
use App\Models\Supplier;
use App\Models\Warehouse;
use App\Models\IngredientStock;
use Illuminate\Http\Request;

class IngredientController extends Controller
{
    public function index()
    {
        $ingredients = Ingredient::with(['supplier', 'stocks.warehouse'])->get();
        $suppliers = Supplier::all();
        $warehouses = Warehouse::all();
        return view('admin.ingredients.index', compact('ingredients', 'suppliers', 'warehouses'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'ingredient_name' => 'required|string|max:255',
            'unit' => 'required|string|max:20',
            'minimum_stock' => 'required|numeric|min:0',
            'cost_per_unit' => 'required|numeric|min:0',
            'supplier_id' => 'nullable|exists:suppliers,id',
        ]);

        $ingredient = Ingredient::create($data);

        // Auto create stock in warehouse 1 if exist
        $warehouse = Warehouse::first();
        if ($warehouse) {
            IngredientStock::create([
                'warehouse_id' => $warehouse->id,
                'ingredient_id' => $ingredient->id,
                'on_hand_qty' => 0,
                'last_movement_at' => now(),
            ]);
        }

        return redirect()->route('admin.ingredients.index')->with('success', 'Bahan baku berhasil ditambahkan');
    }

    public function updateStock(Request $request, Ingredient $ingredient)
    {
        $request->validate([
            'warehouse_id' => 'required|exists:warehouses,id',
            'added_qty' => 'required|numeric|min:0',
        ]);

        $stock = IngredientStock::firstOrCreate([
            'warehouse_id' => $request->warehouse_id,
            'ingredient_id' => $ingredient->id,
        ], [
            'on_hand_qty' => 0,
        ]);

        $stock->increment('on_hand_qty', $request->added_qty);
        $stock->last_movement_at = now();
        $stock->save();

        return redirect()->route('admin.ingredients.index')->with('success', 'Stok berhasil ditambah');
    }

    public function destroy(Ingredient $ingredient)
    {
        $ingredient->delete();
        return redirect()->route('admin.ingredients.index')->with('success', 'Bahan baku dihapus');
    }
}
