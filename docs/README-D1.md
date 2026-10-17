# L&T VERO / Cloudflare D1

## Cấu trúc dữ liệu

`database/schema.sql` tạo các bảng:

- `categories`, `products`, `product_images`, `product_variants`: catalog, ảnh, SKU, size, màu, giá và tồn kho.
- `collections`, `collection_products`: bộ sưu tập.
- `combos`, `combo_products`: executive combo.
- `customers`, `orders`, `order_items`: khách hàng và đơn hàng.
- `payment_transactions`: QR payment/COD transaction state.
- `appointments`: lịch may đo tại showroom, văn phòng hoặc nhà.
- `testimonials`, `newsletter_subscribers`: social proof và newsletter.

Hai view báo cáo có sẵn:

- `sales_summary`: số đơn và doanh thu theo ngày.
- `product_sales_summary`: số lượng bán và gross sales theo sản phẩm.

## Tạo database

```bash
npx wrangler d1 create lt-vero-production
```

Copy `database_id` được trả về vào `wrangler.toml`, sau đó chạy schema:

```bash
npx wrangler d1 execute lt-vero-production --remote --file=./database/schema.sql
```

Chạy Worker local:

```bash
npx wrangler dev
```

## API quản trị

- `GET /api/admin/overview`: KPI doanh thu, đơn hàng, khách hàng và lịch hẹn.
- `GET /api/admin/sales?days=30`: doanh thu theo ngày.
- `GET /api/products`: danh sách sản phẩm kèm tồn kho khả dụng.
- `POST /api/products`: tạo sản phẩm.
- `PATCH /api/products/:id`: cập nhật sản phẩm.
- `DELETE /api/products/:id`: archive sản phẩm, không xóa dữ liệu bán hàng.

## Trang quản trị

Mở `admin/index.html` để xem dashboard ngay với dữ liệu demo. Khi Worker được chạy cùng origin, dashboard tự gọi D1 API; nếu API chưa có, trang tự chuyển sang dữ liệu demo và vẫn cho phép thử form thêm sản phẩm.

## Cấu trúc thư mục

```text
frontend/   Website khách hàng: HTML, CSS, JavaScript
admin/      Dashboard quản trị và quản lý sản phẩm
backend/    Cloudflare Worker API
database/   Cloudflare D1 SQLite schema
docs/       Tài liệu triển khai
index.html  Entry redirect tương thích cho hosting static
admin.html  Entry redirect tương thích cho link admin cũ
wrangler.toml  Cấu hình Cloudflare ở root
```

Trong production cần bổ sung authentication cho toàn bộ `/api/admin/*` và `/api/products` trước khi public Worker.