# API Contract (Initial)

## Auth
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/auth/logout`

## Master Data
- `GET /api/products?active_only=1`

## Sales
- `POST /api/sales`
- `GET /api/sales/history?outlet_id=1&limit=30`
- `GET /api/sales/history?outlet_id=1&limit=30&from=2026-03-01&to=2026-03-04`

`GET /api/sales/history` item response sekarang mengandung `sync_status`.

Example body:
```json
{
  "invoice_number": "INV-20260304-0001",
  "outlet_id": 1,
  "warehouse_id": 1,
  "payment_method": "CASH",
  "order_type": "DINE_IN",
  "items": [
    { "product_id": 1, "quantity": 2, "price": 25000 }
  ]
}
```

## Purchasing
- `POST /api/purchases/{purchaseId}/receive`

## Printer
- `GET /api/printers?outlet_id=1`
- `POST /api/printers`

## Sync
- `POST /api/sync/push`
- `GET /api/sync/pull?outlet_id=1&since=2026-03-01%2000:00:00`
- `POST /api/sync/retry-audit-logs`
- `GET /api/sync/retry-audit-logs?outlet_id=1&limit=100`
- `POST /api/sync/void-item-logs`
- `GET /api/sync/void-item-logs?outlet_id=1&limit=100`
- `GET /api/sync/log-overview?outlet_id=1&from=2026-03-01&to=2026-03-05`

## Dashboard Admin
- `GET /api/dashboard/summary?outlet_id=1&date=2026-03-04`
- `GET /api/dashboard/sales-trend?outlet_id=1&days=7`
- `GET /api/dashboard/top-products?outlet_id=1&from=2026-03-01&to=2026-03-04&limit=10`
- `GET /api/dashboard/low-stock?outlet_id=1&limit=50`
