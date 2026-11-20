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
        version: 13,
        onCreate: (db, _) async {
          await db.execute("CREATE TABLE businesses(id TEXT PRIMARY KEY,name TEXT NOT NULL,business_type TEXT NOT NULL,country_code TEXT NOT NULL,currency_code TEXT NOT NULL,timezone TEXT NOT NULL,default_warehouse_id TEXT,created_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
          await db.execute("CREATE TABLE products(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,name TEXT NOT NULL,sku TEXT,barcode TEXT,category TEXT,unit TEXT NOT NULL DEFAULT 'unité',purchase_price REAL NOT NULL DEFAULT 0,sale_price REAL NOT NULL DEFAULT 0,quantity REAL NOT NULL DEFAULT 0,min_quantity REAL NOT NULL DEFAULT 0,tax_rate REAL NOT NULL DEFAULT 0,track_stock INTEGER NOT NULL DEFAULT 1,is_active INTEGER NOT NULL DEFAULT 1,updated_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
          await db.execute('CREATE INDEX products_business_idx ON products(business_id,name)');
          await db.execute("CREATE TABLE outbox(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,entity_type TEXT NOT NULL,entity_id TEXT NOT NULL,operation TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0,status TEXT NOT NULL DEFAULT 'queued',last_error TEXT");
          await db.execute('CREATE INDEX outbox_status_idx ON outbox(status,created_at)');
          await db.execute('CREATE TABLE app_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
          await _createInventoryTables(db);
          await _createSalesTables(db);
          await _createCustomersTable(db);
          await _createSuppliersTable(db);
          await _createPurchasesTables(db);
          await _createExpensesTable(db);
          await _createCustomerPaymentsTable(db);
          await _createSaleReturnsTables(db);
          await _createCashTables(db);
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
          if (oldVersion < 4) await db.execute('ALTER TABLE businesses ADD COLUMN default_warehouse_id TEXT');
          if (oldVersion < 5) await _createCustomersTable(db);
          if (oldVersion < 6) await _createSuppliersTable(db);
          if (oldVersion < 7) await _createPurchasesTables(db);
          if (oldVersion < 8) await _createExpensesTable(db);
          if (oldVersion < 9) await _createCustomerPaymentsTable(db);
          if (oldVersion < 10) await _createSaleReturnsTables(db);
          if (oldVersion < 11) await _createCashTables(db);
          if (oldVersion < 12) await db.execute('ALTER TABLE products ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
          if (oldVersion < 13) await db.execute('ALTER TABLE outbox ADD COLUMN last_error TEXT');
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

  Future<void> _createCustomersTable(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS customers(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,name TEXT NOT NULL,phone TEXT,email TEXT,address TEXT,notes TEXT,balance_due REAL NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
    await db.execute('CREATE INDEX IF NOT EXISTS customers_business_name_idx ON customers(business_id,name)');
  }

  Future<void> _createSuppliersTable(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS suppliers(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,name TEXT NOT NULL,phone TEXT,email TEXT,address TEXT,notes TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
    await db.execute('CREATE INDEX IF NOT EXISTS suppliers_business_name_idx ON suppliers(business_id,name)');
  }

  Future<void> _createCashTables(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS cash_registers(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,name TEXT NOT NULL,location_id TEXT,is_active INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,UNIQUE(business_id,name))");
    await db.execute("CREATE TABLE IF NOT EXISTS cash_sessions(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,register_id TEXT NOT NULL,opened_by TEXT,closed_by TEXT,opening_amount REAL NOT NULL DEFAULT 0,closing_amount REAL,expected_amount REAL,opened_at TEXT NOT NULL,closed_at TEXT,status TEXT NOT NULL DEFAULT 'open',created_at TEXT NOT NULL,updated_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
    await db.execute('CREATE INDEX IF NOT EXISTS cash_sessions_business_opened_idx ON cash_sessions(business_id,opened_at)');
    await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS cash_sessions_one_open_register_idx ON cash_sessions(register_id) WHERE status='open'");
  }

  Future<void> _createSaleReturnsTables(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS sale_returns(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,sale_id TEXT NOT NULL,return_number TEXT NOT NULL,reason TEXT NOT NULL,refund_method TEXT NOT NULL,refund_amount REAL NOT NULL,status TEXT NOT NULL DEFAULT 'completed',returned_at TEXT NOT NULL,created_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
    await db.execute("CREATE TABLE IF NOT EXISTS sale_return_items(id TEXT PRIMARY KEY,return_id TEXT NOT NULL,sale_item_id TEXT NOT NULL,product_id TEXT,product_name_snapshot TEXT NOT NULL,quantity REAL NOT NULL,unit_price REAL NOT NULL,refund_amount REAL NOT NULL)");
    await db.execute('CREATE INDEX IF NOT EXISTS sale_returns_sale_idx ON sale_returns(sale_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS sale_return_items_return_idx ON sale_return_items(return_id)');
  }

  Future<void> _createCustomerPaymentsTable(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS customer_payments(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,customer_id TEXT NOT NULL,amount REAL NOT NULL,payment_method TEXT NOT NULL,note TEXT,paid_at TEXT NOT NULL,created_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
    await db.execute('CREATE INDEX IF NOT EXISTS customer_payments_business_customer_time_idx ON customer_payments(business_id,customer_id,paid_at)');
  }

  Future<void> _createExpensesTable(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS expenses(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,category TEXT NOT NULL,description TEXT NOT NULL,amount REAL NOT NULL,currency_code TEXT NOT NULL,paid_at TEXT NOT NULL,payment_method TEXT,created_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
    await db.execute('CREATE INDEX IF NOT EXISTS expenses_business_time_idx ON expenses(business_id,paid_at)');
  }

  Future<void> _createPurchasesTables(DatabaseExecutor db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS purchases(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,supplier_id TEXT,warehouse_id TEXT NOT NULL,purchase_number TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'received',currency_code TEXT NOT NULL,total REAL NOT NULL DEFAULT 0,ordered_at TEXT,received_at TEXT,created_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
    await db.execute('CREATE INDEX IF NOT EXISTS purchases_business_time_idx ON purchases(business_id,created_at)');
    await db.execute("CREATE TABLE IF NOT EXISTS purchase_items(id TEXT PRIMARY KEY,purchase_id TEXT NOT NULL,product_id TEXT,product_name_snapshot TEXT NOT NULL,quantity REAL NOT NULL,unit_cost REAL NOT NULL,line_total REAL NOT NULL)");
    await db.execute('CREATE INDEX IF NOT EXISTS purchase_items_purchase_idx ON purchase_items(purchase_id)');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
