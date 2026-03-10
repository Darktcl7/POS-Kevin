<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class SyncController extends Controller
{
    public function push(Request $request)
    {
        $data = $request->validate([
            'device_id' => ['required', 'string', 'max:120'],
            'operations' => ['required', 'array', 'min:1'],
            'operations.*.entity_type' => ['required', 'string', 'max:40'],
            'operations.*.operation' => ['required', 'string', 'max:20'],
            'operations.*.entity_local_id' => ['nullable', 'string', 'max:120'],
            'operations.*.entity_server_id' => ['nullable', 'integer'],
            'operations.*.payload' => ['required', 'array'],
        ]);

        $now = Carbon::now();
        $rows = [];

        foreach ($data['operations'] as $op) {
            $rows[] = [
                'device_id' => $data['device_id'],
                'entity_type' => $op['entity_type'],
                'operation' => $op['operation'],
                'entity_local_id' => $op['entity_local_id'] ?? null,
                'entity_server_id' => $op['entity_server_id'] ?? null,
                'payload' => json_encode($op['payload']),
                'status' => 'SYNCED',
                'retry_count' => 0,
                'last_try_at' => $now,
                'synced_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        DB::table('sync_outbox')->insert($rows);

        return response()->json(['message' => 'Sync push received', 'count' => count($rows)]);
    }

    public function pull(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['required', 'integer', 'exists:outlets,id'],
            'since' => ['nullable', 'date'],
        ]);

        $since = $data['since'] ?? now()->subDays(7)->toDateTimeString();

        $products = DB::table('products')
            ->where('updated_at', '>=', $since)
            ->orderBy('updated_at')
            ->get();

        $ingredients = DB::table('ingredients')
            ->where('updated_at', '>=', $since)
            ->orderBy('updated_at')
            ->get();

        $recipes = DB::table('recipes')
            ->where('updated_at', '>=', $since)
            ->orderBy('updated_at')
            ->get();

        $printers = DB::table('printers')
            ->where('outlet_id', $data['outlet_id'])
            ->where('updated_at', '>=', $since)
            ->orderBy('updated_at')
            ->get();

        return response()->json([
            'server_time' => now()->toDateTimeString(),
            'products' => $products,
            'ingredients' => $ingredients,
            'recipes' => $recipes,
            'printers' => $printers,
        ]);
    }

    public function pushRetryAuditLogs(Request $request)
    {
        $data = $request->validate([
            'device_id' => ['required', 'string', 'max:120'],
            'outlet_id' => ['nullable', 'integer', 'exists:outlets,id'],
            'logs' => ['required', 'array', 'min:1'],
            'logs.*.local_log_id' => ['required', 'string', 'max:120'],
            'logs.*.action_type' => ['required', 'string', 'max:40'],
            'logs.*.invoice_number' => ['required', 'string', 'max:120'],
            'logs.*.queue_id' => ['nullable', 'string', 'max:120'],
            'logs.*.status' => ['required', 'string', 'max:30'],
            'logs.*.result_message' => ['required', 'string', 'max:4000'],
            'logs.*.performed_by' => ['nullable', 'string', 'max:190'],
            'logs.*.logged_at' => ['nullable', 'date'],
        ]);

        $now = Carbon::now();
        $acceptedLocalIds = [];
        $upsertRows = [];

        DB::transaction(function () use ($data, $now, &$acceptedLocalIds) {
            foreach ($data['logs'] as $log) {
                $upsertRows[] = [
                    'device_id' => $data['device_id'],
                    'local_log_id' => $log['local_log_id'],
                    'outlet_id' => $data['outlet_id'] ?? null,
                    'action_type' => $log['action_type'],
                    'invoice_number' => $log['invoice_number'],
                    'queue_id' => $log['queue_id'] ?? null,
                    'status' => $log['status'],
                    'result_message' => $log['result_message'],
                    'performed_by' => $log['performed_by'] ?? null,
                    'logged_at' => isset($log['logged_at']) ? Carbon::parse($log['logged_at']) : $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
                $acceptedLocalIds[] = $log['local_log_id'];
            }

            if (! empty($upsertRows)) {
                DB::table('retry_audit_logs')->upsert(
                    $upsertRows,
                    ['device_id', 'local_log_id'],
                    ['outlet_id', 'action_type', 'invoice_number', 'queue_id', 'status', 'result_message', 'performed_by', 'logged_at', 'updated_at']
                );
            }
        });

        return response()->json([
            'message' => 'Retry audit logs synced',
            'count' => count($acceptedLocalIds),
            'accepted_local_ids' => $acceptedLocalIds,
        ]);
    }

    public function listRetryAuditLogs(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['nullable', 'integer', 'exists:outlets,id'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
            'status' => ['nullable', 'string', 'in:SUCCESS,FAILED'],
            'page' => ['nullable', 'integer', 'min:1'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:200'],
        ]);

        $limit = (int) ($data['limit'] ?? 100);
        $page = (int) ($data['page'] ?? 1);
        $query = DB::table('retry_audit_logs')->orderByDesc('id');

        if (isset($data['outlet_id'])) {
            $query->where('outlet_id', $data['outlet_id']);
        }
        if (isset($data['from'])) {
            $query->where('logged_at', '>=', Carbon::parse($data['from'])->startOfDay());
        }
        if (isset($data['to'])) {
            $query->where('logged_at', '<=', Carbon::parse($data['to'])->endOfDay());
        }
        if (isset($data['status'])) {
            $query->where('status', $data['status']);
        }

        $total = (clone $query)->count();
        $lastPage = max((int) ceil($total / max($limit, 1)), 1);
        if ($page > $lastPage) {
            $page = $lastPage;
        }
        $offset = ($page - 1) * $limit;
        $items = $query->offset($offset)->limit($limit)->get();

        return response()->json([
            'items' => $items,
            'meta' => [
                'page' => $page,
                'limit' => $limit,
                'total' => $total,
                'last_page' => $lastPage,
            ],
        ]);
    }

    public function pushVoidItemLogs(Request $request)
    {
        $data = $request->validate([
            'device_id' => ['required', 'string', 'max:120'],
            'outlet_id' => ['nullable', 'integer', 'exists:outlets,id'],
            'logs' => ['required', 'array', 'min:1'],
            'logs.*.local_log_id' => ['required', 'string', 'max:120'],
            'logs.*.product_name' => ['required', 'string', 'max:255'],
            'logs.*.quantity' => ['required', 'integer', 'min:1'],
            'logs.*.reason' => ['required', 'string', 'max:4000'],
            'logs.*.performed_by' => ['nullable', 'string', 'max:190'],
            'logs.*.logged_at' => ['nullable', 'date'],
        ]);

        $now = Carbon::now();
        $acceptedLocalIds = [];
        $upsertRows = [];

        DB::transaction(function () use ($data, $now, &$acceptedLocalIds, &$upsertRows) {
            foreach ($data['logs'] as $log) {
                $upsertRows[] = [
                    'device_id' => $data['device_id'],
                    'local_log_id' => $log['local_log_id'],
                    'outlet_id' => $data['outlet_id'] ?? null,
                    'product_name' => $log['product_name'],
                    'quantity' => $log['quantity'],
                    'reason' => $log['reason'],
                    'performed_by' => $log['performed_by'] ?? null,
                    'logged_at' => isset($log['logged_at']) ? Carbon::parse($log['logged_at']) : $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
                $acceptedLocalIds[] = $log['local_log_id'];
            }

            if (! empty($upsertRows)) {
                DB::table('void_item_logs')->upsert(
                    $upsertRows,
                    ['device_id', 'local_log_id'],
                    ['outlet_id', 'product_name', 'quantity', 'reason', 'performed_by', 'logged_at', 'updated_at']
                );
            }
        });

        return response()->json([
            'message' => 'Void item logs synced',
            'count' => count($acceptedLocalIds),
            'accepted_local_ids' => $acceptedLocalIds,
        ]);
    }

    public function listVoidItemLogs(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['nullable', 'integer', 'exists:outlets,id'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
            'page' => ['nullable', 'integer', 'min:1'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:200'],
        ]);

        $limit = (int) ($data['limit'] ?? 100);
        $page = (int) ($data['page'] ?? 1);
        $query = DB::table('void_item_logs')->orderByDesc('id');

        if (isset($data['outlet_id'])) {
            $query->where('outlet_id', $data['outlet_id']);
        }
        if (isset($data['from'])) {
            $query->where('logged_at', '>=', Carbon::parse($data['from'])->startOfDay());
        }
        if (isset($data['to'])) {
            $query->where('logged_at', '<=', Carbon::parse($data['to'])->endOfDay());
        }

        $total = (clone $query)->count();
        $lastPage = max((int) ceil($total / max($limit, 1)), 1);
        if ($page > $lastPage) {
            $page = $lastPage;
        }
        $offset = ($page - 1) * $limit;
        $items = $query->offset($offset)->limit($limit)->get();

        return response()->json([
            'items' => $items,
            'meta' => [
                'page' => $page,
                'limit' => $limit,
                'total' => $total,
                'last_page' => $lastPage,
            ],
        ]);
    }

    public function logOverview(Request $request)
    {
        $data = $request->validate([
            'outlet_id' => ['nullable', 'integer', 'exists:outlets,id'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
        ]);

        $from = isset($data['from']) ? Carbon::parse($data['from'])->startOfDay() : now()->subDays(6)->startOfDay();
        $to = isset($data['to']) ? Carbon::parse($data['to'])->endOfDay() : now()->endOfDay();

        $retryQuery = DB::table('retry_audit_logs')
            ->whereBetween('logged_at', [$from, $to]);
        $voidQuery = DB::table('void_item_logs')
            ->whereBetween('logged_at', [$from, $to]);

        if (isset($data['outlet_id'])) {
            $retryQuery->where('outlet_id', $data['outlet_id']);
            $voidQuery->where('outlet_id', $data['outlet_id']);
        }

        $retryPerDay = (clone $retryQuery)
            ->selectRaw('DATE(logged_at) as log_date, COUNT(*) as total')
            ->groupBy(DB::raw('DATE(logged_at)'))
            ->orderBy(DB::raw('DATE(logged_at)'))
            ->get();

        $voidPerDay = (clone $voidQuery)
            ->selectRaw('DATE(logged_at) as log_date, COUNT(*) as total')
            ->groupBy(DB::raw('DATE(logged_at)'))
            ->orderBy(DB::raw('DATE(logged_at)'))
            ->get();

        return response()->json([
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'retry_total' => (clone $retryQuery)->count(),
            'void_total' => (clone $voidQuery)->count(),
            'retry_per_day' => $retryPerDay,
            'void_per_day' => $voidPerDay,
        ]);
    }
}
