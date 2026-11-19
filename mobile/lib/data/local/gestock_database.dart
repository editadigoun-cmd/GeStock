import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class GeStockDatabase {
  GeStockDatabase({String? path, DatabaseFactory? factory}) : _path = path, _factory = factory;
  final String? _path;
  final DatabaseFactory? _factory;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final filePath = _path ?? p.join(await getDatabasesPath(), 'gestock.db');
    final factory = _factory ?? databaseFactory;
    _database = await factory.openDatabase(
      filePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute("CREATE TABLE businesses(id TEXT PRIMARY KEY,name TEXT NOT NULL,business_type TEXT NOT NULL,country_code TEXT NOT NULL,currency_code TEXT NOT NULL,timezone TEXT NOT NULL,created_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
          await db.execute("CREATE TABLE products(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,name TEXT NOT NULL,sku TEXT,barcode TEXT,category TEXT,unit TEXT NOT NULL DEFAULT 'unité',purchase_price REAL NOT NULL DEFAULT 0,sale_price REAL NOT NULL DEFAULT 0,quantity REAL NOT NULL DEFAULT 0,min_quantity REAL NOT NULL DEFAULT 0,tax_rate REAL NOT NULL DEFAULT 0,track_stock INTEGER NOT NULL DEFAULT 1,updated_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
          await db.execute('CREATE INDEX products_business_idx ON products(business_id,name)');
          await db.execute("CREATE TABLE outbox(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,entity_type TEXT NOT NULL,entity_id TEXT NOT NULL,operation TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0,status TEXT NOT NULL DEFAULT 'queued')");
          await db.execute('CREATE INDEX outbox_status_idx ON outbox(status,created_at)');
          await db.execute('CREATE TABLE app_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
          await _createInventoryTables(db);
          await _createSalesTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createInventoryTables(db);
          if (oldVersion < 3) {
            if (oldVersion >= 2) {
              await db.execute('ALTER TABLE stock_movements ADD COLUMN source_type TEXT');
              await db.execute('ALTER TABLE stock_movements ADD COLUMN source_id TEXT');
            }
            await db.execute('ALTER TABLE products ADD COLUMN tax_rate REAL NOT NULL DEFAULT 0');
            await db.execute('ALTER TABLE products ADD COLUMN track_stock INTEGER NOT NULL DEFAULT 1');
            await _createSalesTables(db);
          }
        },
      ),
    );
    return _database!;
  }

  Future<void> _createInventoryTables(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS warehouses(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,name TEXT NOT NULL,is_default INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL)");
    await db.execute('CREATE INDEX IF NOT EXISTS warehouses_business_idx ON warehouses(business_id)');
    await db.execute("CREATE TABLE IF NOT EXISTS stock_movements(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,warehouse_id TEXT NOT NULL,product_id TEXT NOT NULL,movement_type TEXT NOT NULL,quantity_delta REAL NOT NULL,note TEXT,occurred_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending',source_type TEXT,source_id TEXT)");
    await db.execute('CREATE INDEX IF NOT EXISTS stock_movements_product_idx ON stock_movements(business_id,product_id,occurred_at)');
  }

  Future<void> _createSalesTables(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS sales(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,sale_number TEXT NOT NULL,currency_code TEXT NOT NULL,subtotal REAL NOT NULL,discount_total REAL NOT NULL,tax_total REAL NOT NULL,total REAL NOT NULL,amount_paid REAL NOT NULL,payment_method TEXT NOT NULL,payment_status TEXT NOT NULL,status TEXT NOT NULL,sold_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending',warehouse_id TEXT,customer_id TEXT,created_at TEXT NOT NULL,UNIQUE(business_id,sale_number))");
    await db.execute('CREATE INDEX sales_business_sold_idx ON sales(business_id,sold_at)');
    await db.execute("CREATE TABLE IF NOT EXISTS sale_items(id TEXT PRIMARY KEY,sale_id TEXT NOT NULL,product_id TEXT,product_name_snapshot TEXT NOT NULL,quantity REAL NOT NULL,unit_price REAL NOT NULL,discount_amount REAL NOT NULL DEFAULT 0,tax_amount REAL NOT NULL DEFAULT 0,line_total REAL NOT NULL)");
    await db.execute('CREATE INDEX sale_items_sale_idx ON sale_items(sale_id)');
    await db.execute("CREATE TABLE sale_payments(id TEXT PRIMARY KEY,sale_id TEXT NOT NULL,payment_method TEXT NOT NULL,amount REAL NOT NULL,status TEXT NOT NULL,provider_reference TEXT,paid_at TEXT,created_at TEXT NOT NULL)");
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
