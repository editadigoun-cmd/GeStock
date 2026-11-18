import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
class GeStockDatabase {
 Database? _database;
 Future<Database> get database async {
  if(_database!=null)return _database!;
  final root=await getDatabasesPath();
  _database=await openDatabase(p.join(root,'gestock.db'),version:2,onCreate:(db,_)async{
   await db.execute("CREATE TABLE businesses(id TEXT PRIMARY KEY,name TEXT NOT NULL,business_type TEXT NOT NULL,country_code TEXT NOT NULL,currency_code TEXT NOT NULL,timezone TEXT NOT NULL,created_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
   await db.execute("CREATE TABLE products(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,name TEXT NOT NULL,sku TEXT,barcode TEXT,category TEXT,unit TEXT NOT NULL DEFAULT 'unité',purchase_price REAL NOT NULL DEFAULT 0,sale_price REAL NOT NULL DEFAULT 0,quantity REAL NOT NULL DEFAULT 0,min_quantity REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
   await db.execute('CREATE INDEX products_business_idx ON products(business_id,name)');
   await db.execute("CREATE TABLE outbox(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,entity_type TEXT NOT NULL,entity_id TEXT NOT NULL,operation TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0,status TEXT NOT NULL DEFAULT 'queued')");
   await db.execute('CREATE INDEX outbox_status_idx ON outbox(status,created_at)');
   await db.execute('CREATE TABLE app_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
   await _createInventoryTables(db);
  },onUpgrade:(db,oldVersion,newVersion)async{
   if(oldVersion<2)await _createInventoryTables(db);
  });
  return _database!;
 }
 Future<void> _createInventoryTables(DatabaseExecutor db)async{
  await db.execute("CREATE TABLE IF NOT EXISTS warehouses(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,name TEXT NOT NULL,is_default INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL)");
  await db.execute('CREATE INDEX IF NOT EXISTS warehouses_business_idx ON warehouses(business_id)');
  await db.execute("CREATE TABLE IF NOT EXISTS stock_movements(id TEXT PRIMARY KEY,business_id TEXT NOT NULL,warehouse_id TEXT NOT NULL,product_id TEXT NOT NULL,movement_type TEXT NOT NULL,quantity_delta REAL NOT NULL,note TEXT,occurred_at TEXT NOT NULL,sync_state TEXT NOT NULL DEFAULT 'pending')");
  await db.execute('CREATE INDEX IF NOT EXISTS stock_movements_product_idx ON stock_movements(business_id,product_id,occurred_at)');
 }
 Future<void> close()async{await _database?.close();_database=null;}
}
