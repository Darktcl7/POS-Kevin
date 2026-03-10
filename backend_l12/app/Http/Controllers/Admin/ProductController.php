<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Storage;

class ProductController extends Controller
{
    public function index()
    {
        $products = Product::with('category')->get();
        $categories = Category::all();
        return view('admin.products.index', compact('products', 'categories'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'category_id' => 'required|exists:categories,id',
            'product_name' => 'required|string|max:255',
            'selling_price' => 'required|numeric|min:0',
            'is_active' => 'boolean',
            'photo_file' => 'nullable|image|max:5120',
        ]);

        $data['sku'] = 'SKU-' . strtoupper(Str::random(6));
        $data['tax_percent'] = 0;
        $data['is_active'] = $request->has('is_active');

        if ($request->hasFile('photo_file')) {
            $data['photo'] = 'storage/' . $request->file('photo_file')->store('products', 'public');
        }

        Product::create($data);

        return redirect()->route('admin.products.index')->with('success', 'Produk jualan berhasil ditambahkan.');
    }

    public function destroy(Product $product)
    {
        $product->delete();
        return redirect()->route('admin.products.index')->with('success', 'Produk dihapus.');
    }
}
