<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $products = DB::table('products')
            ->join('categories', 'categories.id', '=', 'products.category_id')
            ->select([
                'products.id',
                'products.product_name',
                'products.sku',
                'products.selling_price',
                'products.cost_price',
                'products.tax_percent',
                'products.is_active',
                'products.photo',
                'categories.category_name',
            ])
            ->when($request->boolean('active_only', true), function ($query) {
                $query->where('products.is_active', true);
            })
            ->orderBy('products.product_name')
            ->get()
            ->map(function ($product) {
                // Return clear full URL for photo if present
                $url = null;
                if (!empty($product->photo)) {
                    $url = filter_var($product->photo, FILTER_VALIDATE_URL) ? $product->photo : url('storage/' . $product->photo);
                }
                
                $product->image_url = $url;
                unset($product->photo);
                return $product;
            });

        return response()->json($products);
    }

    public function categories()
    {
        return response()->json(DB::table('categories')->oldest('id')->get());
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'category_id' => 'required|exists:categories,id',
            'product_name' => 'required|string|max:255',
            'sku' => 'nullable|string|max:60|unique:products,sku',
            'selling_price' => 'required|numeric|min:0',
            'cost_price' => 'nullable|numeric|min:0',
            'tax_percent' => 'nullable|numeric|min:0',
            'is_active' => 'boolean',
        ]);

        if ($request->hasFile('photo')) {
            $path = $request->file('photo')->store('products', 'public');
            $data['photo'] = $path;
        } elseif ($request->has('photo') && is_string($request->input('photo'))) {
            $data['photo'] = $request->input('photo');
        }

        $data['sku'] = $data['sku'] ?? strtoupper(\Illuminate\Support\Str::random(6));
        $data['is_active'] = $data['is_active'] ?? true;
        
        $id = DB::table('products')->insertGetId(array_merge($data, [
            'created_at' => now(),
            'updated_at' => now(),
        ]));
        
        return response()->json(['success' => true, 'id' => $id]);
    }

    public function update(Request $request, $id)
    {
        $data = $request->validate([
            'category_id' => 'sometimes|exists:categories,id',
            'product_name' => 'sometimes|string|max:255',
            'sku' => "sometimes|string|max:60|unique:products,sku,{$id}",
            'selling_price' => 'sometimes|numeric|min:0',
            'cost_price' => 'nullable|numeric|min:0',
            'tax_percent' => 'nullable|numeric|min:0',
            'is_active' => 'boolean',
        ]);

        if ($request->hasFile('photo')) {
            $path = $request->file('photo')->store('products', 'public');
            $data['photo'] = $path;
        } elseif ($request->has('photo') && is_string($request->input('photo')) && !empty($request->input('photo'))) {
            $data['photo'] = $request->input('photo');
        } else if ($request->has('photo') && empty($request->input('photo'))) {
            $data['photo'] = null; // if they cleared it
        }

        $data['updated_at'] = now();

        DB::table('products')->where('id', $id)->update($data);
        
        return response()->json(['success' => true]);
    }

    public function destroy($id)
    {
        DB::table('products')->where('id', $id)->delete();
        return response()->json(['success' => true]);
    }
}
