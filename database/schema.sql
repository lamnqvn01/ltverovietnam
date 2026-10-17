PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  image_url TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  sku TEXT NOT NULL UNIQUE,
  description TEXT,
  material TEXT,
  badge TEXT,
  base_price INTEGER NOT NULL CHECK (base_price >= 0),
  compare_at_price INTEGER CHECK (compare_at_price IS NULL OR compare_at_price >= base_price),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'archived')),
  is_tailored INTEGER NOT NULL DEFAULT 0 CHECK (is_tailored IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS product_images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  alt_text TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0, 1))
);

CREATE TABLE IF NOT EXISTS product_variants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sku TEXT NOT NULL UNIQUE,
  color TEXT,
  size TEXT,
  price INTEGER CHECK (price IS NULL OR price >= 0),
  stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
  reserved_quantity INTEGER NOT NULL DEFAULT 0 CHECK (reserved_quantity >= 0),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
);

CREATE TABLE IF NOT EXISTS collections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  image_url TEXT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'archived')),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS collection_products (
  collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (collection_id, product_id)
);

CREATE TABLE IF NOT EXISTS combos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  image_url TEXT,
  original_price INTEGER NOT NULL CHECK (original_price >= 0),
  combo_price INTEGER NOT NULL CHECK (combo_price >= 0 AND combo_price <= original_price),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'archived')),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS combo_products (
  combo_id INTEGER NOT NULL REFERENCES combos(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  PRIMARY KEY (combo_id, product_id)
);

CREATE TABLE IF NOT EXISTS customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  address TEXT,
  city TEXT,
  district TEXT,
  ward TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_code TEXT NOT NULL UNIQUE,
  customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'preparing', 'shipping', 'delivered', 'cancelled')),
  payment_method TEXT NOT NULL CHECK (payment_method IN ('qr_code', 'cod')),
  payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'pending', 'paid', 'failed', 'refunded')),
  subtotal INTEGER NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
  shipping_fee INTEGER NOT NULL DEFAULT 0 CHECK (shipping_fee >= 0),
  discount_amount INTEGER NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  total_amount INTEGER NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  note TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS order_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
  variant_id INTEGER REFERENCES product_variants(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  sku TEXT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price INTEGER NOT NULL CHECK (unit_price >= 0),
  line_total INTEGER NOT NULL CHECK (line_total >= 0)
);

CREATE TABLE IF NOT EXISTS payment_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  provider TEXT NOT NULL DEFAULT 'manual_qr',
  transaction_code TEXT,
  amount INTEGER NOT NULL CHECK (amount >= 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'expired')),
  paid_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS appointments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
  service_type TEXT NOT NULL CHECK (service_type IN ('showroom', 'office', 'home')),
  preferred_at TEXT,
  status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'confirmed', 'completed', 'cancelled')),
  note TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS testimonials (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_name TEXT NOT NULL,
  customer_role TEXT,
  quote TEXT NOT NULL,
  rating INTEGER NOT NULL DEFAULT 5 CHECK (rating BETWEEN 1 AND 5),
  is_published INTEGER NOT NULL DEFAULT 0 CHECK (is_published IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS newsletter_subscribers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'subscribed' CHECK (status IN ('subscribed', 'unsubscribed')),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_products_status ON products(status);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_variants_product ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_orders_status_created ON orders(status, created_at);
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments(status);

CREATE VIEW IF NOT EXISTS sales_summary AS
SELECT date(created_at) AS sale_date, COUNT(*) AS order_count,
  SUM(CASE WHEN payment_status = 'paid' AND status != 'cancelled' THEN total_amount ELSE 0 END) AS revenue
FROM orders GROUP BY date(created_at);

CREATE VIEW IF NOT EXISTS product_sales_summary AS
SELECT oi.product_id, oi.product_name, SUM(oi.quantity) AS units_sold,
  SUM(oi.line_total) AS gross_sales
FROM order_items oi JOIN orders o ON o.id = oi.order_id
WHERE o.payment_status = 'paid' AND o.status != 'cancelled'
GROUP BY oi.product_id, oi.product_name;

INSERT OR IGNORE INTO categories (name, slug, description, sort_order) VALUES
  ('Suit & Blazer', 'suit-blazer', 'May đo và ready-to-wear dành cho executive.', 1),
  ('Shirt', 'shirt', 'Sơ mi premium cho tủ đồ công sở.', 2),
  ('Trousers', 'trousers', 'Quần âu với phom dáng cân bằng.', 3),
  ('Leather & Accessories', 'leather-accessories', 'Giày, thắt lưng và phụ kiện.', 4);

INSERT OR IGNORE INTO products (category_id, name, slug, sku, description, material, badge, base_price, status, is_tailored)
SELECT id, 'Signature Navy Suit', 'signature-navy-suit', 'LTV-SUIT-NAVY-001', 'Cấu trúc mềm và phom executive.', 'Wool blend Italy', 'BEST SELLER', 18900000, 'active', 1 FROM categories WHERE slug = 'suit-blazer';
INSERT OR IGNORE INTO products (category_id, name, slug, sku, description, material, badge, base_price, status)
SELECT id, 'Executive White Shirt', 'executive-white-shirt', 'LTV-SHIRT-WHITE-001', 'Áo sơ mi cotton cổ spread.', 'Premium cotton', 'ESSENTIAL', 2900000, 'active' FROM categories WHERE slug = 'shirt';
INSERT OR IGNORE INTO products (category_id, name, slug, sku, description, material, badge, base_price, status)
SELECT id, 'Italian Leather Oxford', 'italian-leather-oxford', 'LTV-SHOE-OXFORD-001', 'Oxford da bê full-grain.', 'Full-grain calf leather', 'NEW', 6500000, 'active' FROM categories WHERE slug = 'leather-accessories';
INSERT OR IGNORE INTO products (category_id, name, slug, sku, description, material, badge, base_price, status)
SELECT id, 'Classic Leather Belt', 'classic-leather-belt', 'LTV-BELT-CLASSIC-001', 'Thắt lưng da thật với khóa palladium.', 'Italian leather', 'TIMELESS', 1800000, 'active' FROM categories WHERE slug = 'leather-accessories';