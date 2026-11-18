import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';
class ProductRepository {
 ProductRepository(this.db);
 final GeStockDatabase db;final _uuid=const Uuid();
 Future<List<Map<String,Object?>>> list(String businessId)async{final d=await db.database;return d.query('products',where:'business_id = ?',whereArgs:[businessId],orderBy:'name COLLATE NOCASE');}
 Future<void> save({required String businessId,required String name,required String sku,required double salePrice,required double quantity,required double minQuantity})async{
  final d=await db.database;final id=_uuid.v4();final now=DateTime.now().toUtc().toIso8601String();
  final warehouses=await d.query('warehouses',where:'business_id = ? AND is_default = 1',whereArgs:[businessId],limit:1);
  if(warehouses.isEmpty)throw StateError('Aucun dépôt principal pour cette entreprise.');
  final warehouseId=warehouses.first['id'] as String;
  final payload={'id':id,'business_id':businessId,'name':name.trim(),'sku':sku.trim().isEmpty?null:sku.trim(),'sale_price':salePrice,'quantity':quantity,'min_quantity':minQuantity,'updated_at':now};
  await d.transaction((txn)async{
   await txn.insert('products',{...payload,'unit':'unité','purchase_price':0,'sync_state':'pending'});
   if(quantity>0){final movementId=_uuid.v4();await txn.insert('stock_movements',{'id':movementId,'business_id':businessId,'warehouse_id':warehouseId,'product_id':id,'movement_type':'opening','quantity_delta':quantity,'note':'Stock initial','occurred_at':now});await txn.insert('outbox',{'id':_uuid.v4(),'business_id':businessId,'entity_type':'stock_movement','entity_id':movementId,'operation':'create','payload':jsonEncode({'id':movementId,'business_id':businessId,'warehouse_id':warehouseId,'product_id':id,'movement_type':'opening','quantity_delta':quantity,'note':'Stock initial','occurred_at':now}),'created_at':now});}
   await txn.insert('outbox',{'id':_uuid.v4(),'business_id':businessId,'entity_type':'product','entity_id':id,'operation':'upsert','payload':jsonEncode(payload),'created_at':now});
  });
 }
 Future<void> adjustStock({required String businessId,required String productId,required double delta,required String note})async{
  if(delta==0)throw ArgumentError('La quantité doit être différente de zéro.');
  final d=await db.database;final rows=await d.query('products',where:'id = ? AND business_id = ?',whereArgs:[productId,businessId],limit:1);
  if(rows.isEmpty)throw StateError('Produit introuvable.');
  final current=(rows.first['quantity'] as num).toDouble();final next=current+delta;
  if(next<0)throw StateError('Le stock ne peut pas devenir négatif.');
  final warehouses=await d.query('warehouses',where:'business_id = ? AND is_default = 1',whereArgs:[businessId],limit:1);
  if(warehouses.isEmpty)throw StateError('Dépôt principal introuvable.');
  final now=DateTime.now().toUtc().toIso8601String();final movementId=_uuid.v4();final operationId=_uuid.v4();
  final payload={'id':movementId,'business_id':businessId,'warehouse_id':warehouses.first['id'],'product_id':productId,'movement_type':delta>0?'purchase':'adjustment','quantity_delta':delta,'note':note,'occurred_at':now};
  await d.transaction((txn)async{
   await txn.update('products',{'quantity':next,'updated_at':now,'sync_state':'pending'},where:'id = ? AND business_id = ?',whereArgs:[productId,businessId]);
   await txn.insert('stock_movements',{'id':movementId,'business_id':businessId,'warehouse_id':warehouses.first['id'],'product_id':productId,'movement_type':delta>0?'purchase':'adjustment','quantity_delta':delta,'note':note,'occurred_at':now});
   await txn.insert('outbox',{'id':operationId,'business_id':businessId,'entity_type':'stock_movement','entity_id':movementId,'operation':'create','payload':jsonEncode(payload),'created_at':now});
  });
 }
}
