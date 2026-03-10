<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function summary(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['required', 'integer', 'exists:outlets,id'],
            'date' => ['nullable', 'date'],
        ]);

        $date = Carbon::parse($data['date'] ?? now()->toDateString())->toDateString();

        $salesToday = DB::table('sales')
            ->where('outlet_id', $data['outlet_id'])
            ->whereDate('created_at', $date)
            ->selectRaw('COUNT(*) as trx_count, COALESCE(SUM(total_amount),0) as gross_sales')
            ->first();

        $expenseToday = DB::table('expenses')
            ->where('outlet_id', $data['outlet_id'])
            ->whereDate('expense_date', $date)
            ->selectRaw('COALESCE(SUM(amount),0) as total_expense')
            ->value('total_expense');

        $lowStockCount = DB::table('ingredient_stocks as st')
            ->join('ingredients as i', 'i.id', '=', 'st.ingredient_id')
            ->join('warehouses as w', 'w.id', '=', 'st.warehouse_id')
            ->where('w.outlet_id', $data['outlet_id'])
            ->whereColumn('st.on_hand_qty', '<=', 'i.minimum_stock')
            ->count();

        return response()->json([
            'date' => $date,
            'outlet_id' => (int) $data['outlet_id'],
            'sales_transaction_count' => (int) ($salesToday->trx_count ?? 0),
            'gross_sales' => (float) ($salesToday->gross_sales ?? 0),
            'expense_total' => (float) ($expenseToday ?? 0),
            'net_cashflow' => (float) (($salesToday->gross_sales ?? 0) - ($expenseToday ?? 0)),
            'low_stock_items' => (int) $lowStockCount,
        ]);
    }

    public function salesTrend(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['required', 'integer', 'exists:outlets,id'],
            'days' => ['nullable', 'integer', 'min:1', 'max:90'],
        ]);

        $days = (int) ($data['days'] ?? 7);
        $from = now()->startOfDay()->subDays($days - 1);

        $rows = DB::table('sales')
            ->where('outlet_id', $data['outlet_id'])
            ->where('created_at', '>=', $from)
            ->selectRaw('DATE(created_at) as sale_date, COUNT(*) as trx_count, COALESCE(SUM(total_amount),0) as gross_sales')
            ->groupBy(DB::raw('DATE(created_at)'))
            ->orderBy(DB::raw('DATE(created_at)'))
            ->get();

        return response()->json([
            'outlet_id' => (int) $data['outlet_id'],
            'days' => $days,
            'items' => $rows,
        ]);
    }

    public function topProducts(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['required', 'integer', 'exists:outlets,id'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $from = Carbon::parse($data['from'] ?? now()->subDays(30)->toDateString())->startOfDay();
        $to = Carbon::parse($data['to'] ?? now()->toDateString())->endOfDay();
        $limit = (int) ($data['limit'] ?? 10);

        $rows = DB::table('sale_details as sd')
            ->join('sales as s', 's.id', '=', 'sd.sale_id')
            ->join('products as p', 'p.id', '=', 'sd.product_id')
            ->where('s.outlet_id', $data['outlet_id'])
            ->whereBetween('s.created_at', [$from, $to])
            ->selectRaw('sd.product_id, p.product_name, COALESCE(SUM(sd.quantity),0) as total_qty, COALESCE(SUM(sd.subtotal),0) as total_sales')
            ->groupBy('sd.product_id', 'p.product_name')
            ->orderByDesc('total_qty')
            ->limit($limit)
            ->get();

        return response()->json([
            'outlet_id' => (int) $data['outlet_id'],
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'items' => $rows,
        ]);
    }

    public function lowStock(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['required', 'integer', 'exists:outlets,id'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:200'],
        ]);

        $limit = (int) ($data['limit'] ?? 50);

        $rows = DB::table('ingredient_stocks as st')
            ->join('ingredients as i', 'i.id', '=', 'st.ingredient_id')
            ->join('warehouses as w', 'w.id', '=', 'st.warehouse_id')
            ->where('w.outlet_id', $data['outlet_id'])
            ->whereColumn('st.on_hand_qty', '<=', 'i.minimum_stock')
            ->select([
                'st.ingredient_id',
                'i.ingredient_name',
                'i.unit',
                'st.on_hand_qty',
                'i.minimum_stock',
                'w.warehouse_name',
            ])
            ->orderBy('st.on_hand_qty')
            ->limit($limit)
            ->get();

        return response()->json([
            'outlet_id' => (int) $data['outlet_id'],
            'items' => $rows,
        ]);
    }
}
