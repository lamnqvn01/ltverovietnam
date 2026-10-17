const json = (data, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { 'content-type': 'application/json; charset=utf-8', 'access-control-allow-origin': '*' }
});

const body = async request => {
  try { return await request.json(); } catch { return {}; }
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    if (request.method === 'OPTIONS') return new Response(null, { headers: { 'access-control-allow-origin': '*', 'access-control-allow-methods': 'GET,POST,PATCH,DELETE,OPTIONS', 'access-control-allow-headers': 'content-type' } });
    if (path === '/api/test/semantic-scholar/papers') {
      if (request.method !== 'GET') return json({ error: 'Method not allowed.' }, 405);
      const papers = [
        { paperId: 'TEST-SS-001', title: 'TEST MOCK: Attention Is All You Need', year: 2017, abstract: 'Mock paper for testing Semantic Scholar API integrations.', url: 'https://example.com/test-papers/attention-is-all-you-need' },
        { paperId: 'TEST-SS-002', title: 'TEST MOCK: BERT: Pre-training of Deep Bidirectional Transformers', year: 2019, abstract: 'Mock paper for testing search results and metadata rendering.', url: 'https://example.com/test-papers/bert' },
        { paperId: 'TEST-SS-003', title: 'TEST MOCK: Language Models are Few-Shot Learners', year: 2020, abstract: 'Mock paper for testing multiple result handling.', url: 'https://example.com/test-papers/few-shot-learners' }
      ];
      const query = (url.searchParams.get('query') || '').trim().toLowerCase();
      const results = query ? papers.filter(paper => `${paper.title} ${paper.abstract}`.toLowerCase().includes(query)) : papers;
      return json({ total: results.length, offset: 0, data: results });
    }
    if (!env.DB) return json({ error: 'D1 binding DB is not configured.' }, 503);

    try {
      if (path === '/api/admin/overview' && request.method === 'GET') {
        const [summary, products, orders, appointments] = await Promise.all([
          env.DB.prepare("SELECT COUNT(*) AS orders, COALESCE(SUM(CASE WHEN payment_status = 'paid' AND status != 'cancelled' THEN total_amount ELSE 0 END), 0) AS revenue, COUNT(DISTINCT customer_id) AS customers FROM orders").first(),
          env.DB.prepare("SELECT COUNT(*) AS count FROM products WHERE status = 'active'").first(),
          env.DB.prepare("SELECT order_code, customer_id, status, payment_status, total_amount, created_at FROM orders ORDER BY created_at DESC LIMIT 8").all(),
          env.DB.prepare("SELECT COUNT(*) AS count FROM appointments WHERE status = 'requested'").first()
        ]);
        return json({ summary, active_products: products.count, pending_appointments: appointments.count, recent_orders: orders.results });
      }
      if (path === '/api/admin/sales' && request.method === 'GET') {
        const range = Math.min(Number(url.searchParams.get('days') || 30), 365);
        const sales = await env.DB.prepare("SELECT sale_date, order_count, revenue FROM sales_summary WHERE sale_date >= date('now', ? || ' days') ORDER BY sale_date").bind(-range).all();
        return json({ days: range, sales: sales.results });
      }
      if (path === '/api/products' && request.method === 'GET') {
        const products = await env.DB.prepare("SELECT p.*, c.name AS category_name, COALESCE(SUM(v.stock_quantity - v.reserved_quantity), 0) AS available_stock FROM products p LEFT JOIN categories c ON c.id = p.category_id LEFT JOIN product_variants v ON v.product_id = p.id GROUP BY p.id ORDER BY p.updated_at DESC").all();
        return json(products.results);
      }
      if (path === '/api/products' && request.method === 'POST') {
        const data = await body(request);
        if (!data.name || !data.sku || !Number.isFinite(Number(data.base_price))) return json({ error: 'name, sku and base_price are required.' }, 400);
        const slug = data.slug || data.name.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
        const result = await env.DB.prepare("INSERT INTO products (category_id, name, slug, sku, description, material, badge, base_price, status, is_tailored) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)").bind(data.category_id || null, data.name, slug, data.sku, data.description || null, data.material || null, data.badge || null, Number(data.base_price), data.status || 'draft', data.is_tailored ? 1 : 0).run();
        return json({ id: result.meta.last_row_id, message: 'Product created.' }, 201);
      }
      const productMatch = path.match(/^\/api\/products\/(\d+)$/);
      if (productMatch && request.method === 'PATCH') {
        const data = await body(request);
        const fields = ['name', 'description', 'material', 'badge', 'base_price', 'status', 'is_tailored'];
        const updates = fields.filter(field => data[field] !== undefined);
        if (!updates.length) return json({ error: 'No editable fields supplied.' }, 400);
        const query = `UPDATE products SET ${updates.map(field => `${field} = ?`).join(', ')}, updated_at = datetime('now') WHERE id = ?`;
        await env.DB.prepare(query).bind(...updates.map(field => data[field]), Number(productMatch[1])).run();
        return json({ message: 'Product updated.' });
      }
      if (productMatch && request.method === 'DELETE') {
        await env.DB.prepare("UPDATE products SET status = 'archived', updated_at = datetime('now') WHERE id = ?").bind(Number(productMatch[1])).run();
        return json({ message: 'Product archived.' });
      }
      return json({ error: 'Not found.' }, 404);
    } catch (error) { return json({ error: error.message }, 500); }
  }
};