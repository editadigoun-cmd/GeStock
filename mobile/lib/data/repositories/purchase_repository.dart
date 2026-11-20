import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';
import 'auth_repository.dart';

class PurchaseRepository {
  PurchaseRepository(this.db, this.auth, {Dio? dio}) : _dio = dio ?? Dio(BaseOptions(baseUrl: const String.fromEnvironment('GESTOCK_API_URL', defaultValue: 'https://gestock-api.ccds22431.workers.dev'), headers: {'Content-Type': 'application/json'}));
  final GeStockDatabase db; final AuthRepository auth; final Dio _dio; final _uuid=const Uuid();

  Future<List<Map<String,Object?>>> list(String businessId) async {
    final d=await db.database;
    return d.query('purchases',where:'business_id=?',whereArgs:[businessId],orderBy:'created_at DESC');
  }
  Future<List<Map<String,Object?>>> items(String purchaseId) async {
    final d=await db.database;
    return d.query('purchase_items',where:'purchase_id=?',whereArgs:[purchaseId],orderBy:'rowid');
  }
  Future<void> pullCloud(String businessId) async {
    final token=await auth.getAccessToken();
    final r=await _dio.get('/v1/purchases',queryParameters:{'business_id':businessId},options:Options(headers:{'Authorization':'Bearer $token'}));
    if(r.data is! Map || r.data['data'] is! List) throw StateError('Réponse achats invalide.');
    final d=await db.database; final now=DateTime.now().toUtc().toIso8601String();
    await d.transaction((txn) async {
      for(final raw in (r.data['data'] as List).whereType<Map>()) {
        final p=Map<String,Object?>.from(raw); final id=p['id']?.toString(); if(id==null) continue;
        final pending=await txn.query('outbox',where:"entity_type='purchase' AND entity_id=? AND status IN ('queued','failed','conflict')",whereArgs:[id],limit:1);
        if(pending.isNotEmpty) continue;
        final existing=await txn.query('purchases',where:'id=?',whereArgs:[id],limit:1);
        final values={'id':id,'business_id':businessId,'supplier_id':p['supplier_id'],'warehouse_id':p['warehouse_id'],'purchase_number':p['purchase_number'],'status':p['status']??'received','currency_code':p['currency_code'],'total':p['total']??0,'ordered_at':p['ordered_at'],'received_at':p['received_at'],'created_at':p['created_at']??now,'sync_state':'synced'};
        if(existing.isEmpty) await txn.insert('purchases',values); else await txn.update('purchases',values,where:'id=?',whereArgs:[id]);
        final cloudItems=(p['items'] as List?)??[];
        for(final rawItem in cloudItems.whereType<Map>()) {
          final i=Map<String,Object?>.from(rawItem); final itemId=i['id']?.toString(); if(itemId==null) continue;
          final local=await txn.query('purchase_items',where:'id=?',whereArgs:[itemId],limit:1);
          final itemValues={'id':itemId,'purchase_id':id,'product_id':i['product_id'],'product_name_snapshot':i['product_name_snapshot']??'','quantity':i['quantity']??0,'unit_cost':i['unit_cost']??0,'line_total':i['line_total']??0};
          if(local.isEmpty) await txn.insert('purchase_items',itemValues); else await txn.update('purchase_items',itemValues,where:'id=?',whereArgs:[itemId]);
        }
      }
    });
  }

  Future<String> receive({required String businessId,required String warehouseId,required String currencyCode,String? supplierId,required List<Map<String,Object?>> items}) async {
    if(items.isEmpty) throw StateError('La réception doit contenir au moins un produit.');
    final d=await db.database;
    final normalized=[];
    double total=0;
    for(final raw in items) {
      final productId=raw['product_id']?.toString();
      final quantity=(raw['quantity'] as num?)?.toDouble()??0;
      final unitCost=(raw['unit_cost'] as num?)?.toDouble()??0;
      if(productId==null||quantity<=0||!quantity.isFinite||unitCost<0||!unitCost.isFinite) throw ArgumentError('Produit, quantité ou coût invalide.');
      final product=await d.query('products',where:'id=? AND business_id=?',whereArgs:[productId,businessId],limit:1);
      if(product.isEmpty) throw StateError('Produit introuvable.');
      final lineTotal=(quantity*unitCost*100).round()/100;
      total+=lineTotal;
      normalized.add({'product_id':productId,'product_name_snapshot':product.first['name'],'quantity':quantity,'unit_cost':unitCost,'line_total':lineTotal,'id':_uuid.v4()});
    }
    final id=_uuid.v4();final now=DateTime.now().toUtc().toIso8601String();
    final number='ACH-${now.replaceAll(RegExp(r'[-:T.]'),'').substring(0,14)}-${id.substring(0,4).toUpperCase()}';
    final payload={'id':id,'business_id':businessId,'supplier_id':supplierId,'warehouse_id':warehouseId,'purchase_number':number,'status':'received','currency_code':currencyCode,'total':(total*100).round()/100,'ordered_at':now,'received_at':now,'created_at':now,'items':normalized};
    await d.transaction((txn) async {
      await txn.insert('purchases',{'id':id,'business_id':businessId,'supplier_id':supplierId,'warehouse_id':warehouseId,'purchase_number':number,'status':'received','currency_code':currencyCode,'total':(total*100).round()/100,'ordered_at':now,'received_at':now,'created_at':now,'sync_state':'pending'});
      for(final item in normalized) {
        await txn.insert('purchase_items',{'id':item['id'],'purchase_id':id,'product_id':item['product_id'],'product_name_snapshot':item['product_name_snapshot'],'quantity':item['quantity'],'unit_cost':item['unit_cost'],'line_total':item['line_total']});
        final product=(await txn.query('products',where:'id=?',whereArgs:[item['product_id']],limit:1)).first;
        final current=(product['quantity'] as num?)?.toDouble()??0;
        await txn.update('products',{'quantity':current+(item['quantity'] as num).toDouble(),'updated_at':now},where:'id=?',whereArgs:[item['product_id']]);
        await txn.insert('stock_movements',{'id':_uuid.v4(),'business_id':businessId,'warehouse_id':warehouseId,'product_id':item['product_id'],'movement_type':'purchase','quantity_delta':item['quantity'],'note':'Réception $number','occurred_at':now,'sync_state':'pending','source_type':'purchase','source_id':id});
      }
      await txn.insert('outbox',{'id':id,'business_id':businessId,'entity_type':'purchase','entity_id':id,'operation':'receive','payload':jsonEncode(payload),'created_at':now,'attempts':0,'status':'queued'});
    });
    return id;
  }
}
