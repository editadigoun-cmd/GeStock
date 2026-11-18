import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
class GeStockDatabase {
  Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(p.join(root, 'gestock.db'), version: 1, onCreate: (db, _) async {
      await db.execute("CREATE TABLE businesses(id TEXT PRIMARY KEY, name TEXT NOT NULL, business_type TEXT NOT NULL, country_code TEXT NOT NULL, currency_code TEXT NOT NULL, timezone TEXT NOT NULL, created_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT 'pending')");
      await db.execute("CREATE TABLE products(id TEXT PRIMARY KEY, business_id TEXT NOT NULL, name TEXT NOT NULL, sku TEXT, barcode TEXT, category TEXT, unit TEXT NOT NULL DEFAULT 'unité', purchase_price REAL NOT NULL DEFAULT 0, sale_price REAL NOT NULL DEFAULT 0, quantity REAL NOT NULL DEFAULT 0, min_quantity REAL NOT NULL DEFAULT 0, updated_at TEXT NOT NULL, sync_state TEXT NOT NULL DEFAULT 'pending')");
      await db.execute('CREATE INDEX products_business_idx ON products(business_id, name)');
      await db.execute("CREATE TABLE outbox(id TEXT PRIMARY KEY, business_id TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'queued')");
      await db.execute('CREATE INDEX outbox_status_idx ON outbox(status, created_at)');
      await db.execute('CREATE TABLE app_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    });
    return _database!;
  }
  Future<void> close() async { await _database?.close(); _database = null; }
}
