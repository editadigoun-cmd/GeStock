import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { authGuard, type AppEnv } from './middleware/auth.js';
import { configureDatabase } from './services/db.js';
import { productRoutes } from './routes/products.js';
import { syncRoutes } from './routes/sync.js';
import { stockRoutes } from './routes/stock.js';
import { businessRoutes } from './routes/businesses.js';

const app = new Hono<AppEnv>();
app.use('*', logger());
app.use('/v1/*', cors({
  origin: '*',
  allowHeaders: ['Authorization', 'Content-Type'],
  allowMethods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
}));
app.get('/health', (c) => c.json({ ok: true, service: 'gestock-api', version: '0.2.0' }));
app.get('/health/d1', async (c) => {
  try {
    if (!c.env.DB) return c.json({ ok: false, database: 'D1_NOT_BOUND' }, 503);
    const row = await c.env.DB.prepare("SELECT COUNT(*) AS table_count FROM sqlite_master WHERE type='table' AND name NOT LIKE '_cf_%' AND name NOT LIKE 'd1_%'").first<{ table_count: number }>();
    return c.json({ ok: true, database: 'gestock-db', table_count: row?.table_count ?? 0 });
  } catch (error) {
    console.error('D1 health check failed', error);
    return c.json({ ok: false, database: 'D1_UNAVAILABLE' }, 503);
  }
});
app.use('/v1/*', authGuard);
app.use('/v1/*', async (c, next) => {
  try {
    configureDatabase(c.env.DB!);
    await next();
  } catch (error) {
    console.error('Database initialization failed', error);
    return c.json({ error: 'DATABASE_UNAVAILABLE' }, 503);
  }
});
app.route('/v1/businesses', businessRoutes);
app.route('/v1/products', productRoutes);
app.route('/v1/sync', syncRoutes);
app.route('/v1/stock', stockRoutes);
app.notFound((c) => c.json({ error: 'NOT_FOUND' }, 404));
app.onError((error, c) => {
  console.error(error);
  return c.json({ error: 'INTERNAL_ERROR', message: 'Une erreur interne est survenue.' }, 500);
});

export default app;
