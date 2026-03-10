<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PrinterController extends Controller
{
    public function index(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['required', 'integer', 'exists:outlets,id'],
        ]);

        $printers = DB::table('printers')
            ->where('outlet_id', $data['outlet_id'])
            ->orderByDesc('is_default')
            ->orderBy('printer_name')
            ->get();

        return response()->json($printers);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['required', 'integer', 'exists:outlets,id'],
            'printer_name' => ['required', 'string', 'max:255'],
            'connection_type' => ['required', 'string', 'max:20'],
            'address' => ['nullable', 'string', 'max:120'],
            'port' => ['nullable', 'string', 'max:10'],
            'usb_vendor_id' => ['nullable', 'string', 'max:10'],
            'usb_product_id' => ['nullable', 'string', 'max:10'],
            'paper_size' => ['nullable', 'string', 'max:10'],
            'is_default' => ['nullable', 'boolean'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        if (($data['is_default'] ?? false) === true) {
            DB::table('printers')
                ->where('outlet_id', $data['outlet_id'])
                ->update(['is_default' => false]);
        }

        $id = DB::table('printers')->insertGetId([
            'outlet_id' => $data['outlet_id'],
            'printer_name' => $data['printer_name'],
            'connection_type' => $data['connection_type'],
            'address' => $data['address'] ?? null,
            'port' => $data['port'] ?? null,
            'usb_vendor_id' => $data['usb_vendor_id'] ?? null,
            'usb_product_id' => $data['usb_product_id'] ?? null,
            'paper_size' => $data['paper_size'] ?? '58mm',
            'is_default' => $data['is_default'] ?? false,
            'is_active' => $data['is_active'] ?? true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return response()->json(DB::table('printers')->where('id', $id)->first(), 201);
    }
}
