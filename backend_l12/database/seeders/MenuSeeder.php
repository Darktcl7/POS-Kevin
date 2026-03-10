<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class MenuSeeder extends Seeder
{
    public function run()
    {
        $now = now();

        // 1. Categories
        $categories = ['Kopi', 'Non-Kopi', 'Makanan Utama', 'Snack'];
        $catIds = [];
        foreach ($categories as $cat) {
            $catId = DB::table('categories')->insertGetId([
                'category_name' => $cat,
                'created_at' => $now,
                'updated_at' => $now
            ]);
            $catIds[$cat] = $catId;
        }

        // 2. Ingredients
        $ingredients = [
            'Biji Kopi Espresso' => ['unit' => 'Gram', 'cost' => 150],
            'Susu Segar' => ['unit' => 'ML', 'cost' => 20],
            'Gula Aren' => ['unit' => 'Gram', 'cost' => 50],
            'Teh' => ['unit' => 'Gram', 'cost' => 100],
            'Dada Ayam' => ['unit' => 'Porsi', 'cost' => 12000],
            'Beras' => ['unit' => 'Gram', 'cost' => 15],
            'Kentang' => ['unit' => 'Gram', 'cost' => 25],
            'Minyak Goreng' => ['unit' => 'ML', 'cost' => 15],
            'Es Batu' => ['unit' => 'Gram', 'cost' => 5],
        ];

        $ingIds = [];
        foreach ($ingredients as $name => $data) {
            $ingId = DB::table('ingredients')->insertGetId([
                'ingredient_name' => $name,
                'unit' => $data['unit'],
                'cost_per_unit' => $data['cost'],
                'minimum_stock' => 1000,
                'created_at' => $now,
                'updated_at' => $now
            ]);
            $ingIds[$name] = $ingId;
            
            // Add Stock
            $warehouseId = DB::table('warehouses')->where('is_main', true)->value('id') ?? 1;
            DB::table('ingredient_stocks')->insert([
                'warehouse_id' => $warehouseId,
                'ingredient_id' => $ingId,
                'on_hand_qty' => 50000,
                'last_movement_at' => $now,
                'created_at' => $now,
                'updated_at' => $now
            ]);
        }

        // 3. Products
        $products = [
            [
                'name' => 'Kopi Susu Aren',
                'cat' => 'Kopi',
                'price' => 25000,
                'photo' => 'https://images.unsplash.com/photo-1611162618479-ee3d24aaef8b?w=600&q=80',
                'recipe' => [
                    'Biji Kopi Espresso' => 18,
                    'Susu Segar' => 150,
                    'Gula Aren' => 30,
                    'Es Batu' => 120,
                ]
            ],
            [
                'name' => 'Americano',
                'cat' => 'Kopi',
                'price' => 20000,
                'photo' => 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600&q=80',
                'recipe' => [
                    'Biji Kopi Espresso' => 18,
                    'Es Batu' => 150,
                ]
            ],
            [
                'name' => 'Teh Manis Dingin',
                'cat' => 'Non-Kopi',
                'price' => 12000,
                'photo' => 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&q=80',
                'recipe' => [
                    'Teh' => 15,
                    'Gula Aren' => 20,
                    'Es Batu' => 150,
                ]
            ],
            [
                'name' => 'Nasi Goreng Ayam',
                'cat' => 'Makanan Utama',
                'price' => 35000,
                'photo' => 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&q=80',
                'recipe' => [
                    'Beras' => 200,
                    'Dada Ayam' => 1,
                    'Minyak Goreng' => 30,
                ]
            ],
            [
                'name' => 'Ayam Bakar Madu',
                'cat' => 'Makanan Utama',
                'price' => 40000,
                'photo' => 'https://images.unsplash.com/photo-1598514982205-f36b96d1e8d4?w=600&q=80',
                'recipe' => [
                    'Beras' => 200,
                    'Dada Ayam' => 1,
                ]
            ],
            [
                'name' => 'French Fries',
                'cat' => 'Snack',
                'price' => 25000,
                'photo' => 'https://images.unsplash.com/photo-1576107232684-1279f390859f?w=600&q=80',
                'recipe' => [
                    'Kentang' => 150,
                    'Minyak Goreng' => 100,
                ]
            ],
        ];

        foreach ($products as $prod) {
            $prodId = DB::table('products')->insertGetId([
                'category_id' => $catIds[$prod['cat']],
                'product_name' => $prod['name'],
                'sku' => strtoupper(Str::random(6)),
                'selling_price' => $prod['price'],
                'photo' => $prod['photo'] ?? null,
                'created_at' => $now,
                'updated_at' => $now
            ]);

            // Insert Recipes
            foreach ($prod['recipe'] as $ingName => $qty) {
                DB::table('recipes')->insert([
                    'product_id' => $prodId,
                    'ingredient_id' => $ingIds[$ingName],
                    'quantity_used' => $qty,
                    'created_at' => $now,
                    'updated_at' => $now
                ]);
            }
        }
    }
}
