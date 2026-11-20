import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';

class SaleReturnRepository {
  SaleReturnRepository(this.db);
  final GeStockDatabase db;
  final _uuid=const Uuid();

  Future<List<Map<String,Object?>>> list(String businessId)async{
    final d=await db.database;return d.query('sale_returns',where:'business_id=?',whereArgs:[businessId],orderBy:'returned_at DESC',limit:100);
  }

  Future<void> createReturn({required String businessId,required String saleId,required String reason,required String refundMethod,required Map<String,double> quantities})async{
    if(quantities.isEmpty)throw StateError('Sélectionnez au moins un article à retourner.');
    if(reason.trim().isEmpty)throw StateError('Le motif du retour est obligatoire.');
    if(!['cash','mobile_money','card','bank_transfer','store_credit','other'].contains(refundMethod))throw ArgumentError('Mode de remboursement invalide.');
    final d=await db.database;final returnId=_uuid.v4();final now=DateTime.now().toUtc().toIso8601String();final number='RET-${now.replaceAll(RegExp(r'[-:T.]'), '').substring(0,12)}-${returnId.substring(0,4).toUpperCase()}';
    final saleRows=await d.query('sales',where:'id=? AND business_id=?',whereArgs:[saleId,businessId],limit:1);if(saleRows.isEmpty)throw StateError('Vente introuvable.');
    final items=await d.query('sale_items',where:'sale_id=?',whereArgs:[saleId]);
    final movements=await d.query('stock_movements',where:'source_type=? AND source_id=?',whereArgs:['sale',saleId],limit:100);
    final movementByProduct={for(final m in movements)m['product_id']:m};
    final payloadItems=<Map<String,Object?>>[];double totalRefund=0;
    await d.transaction((txn)async{
      for(final entry in quantities.entries){
        final item=items.firstWhere((x)=>x['id']==entry.key,orElse:()=>throw StateError('Article de vente introuvable.'));
        final qty=entry.value;if(!qty.isFinite||qty<=0)throw ArgumentError('Quantité de retour invalide.');
        final prior=await txn.rawQuery('SELECT COALESCE(SUM(quantity),0) AS qty FROM sale_return_items WHERE sale_item_id=?',[item['id']]);
        final already=(prior.first['qty'] as num).toDouble();final sold=(item['quantity'] as num).toDouble();if(already+qty>sold+1e-8)throw StateError('La quantité retournée dépasse la quantité vendue.');
        final unitRefund=(item['line_total'] as num).toDouble()/sold;final refund=unitRefund*qty;totalRefund+=refund;
        final returnItemId=_uuid.v4();
        final row={'id':returnItemId,'return_id':returnId,'sale_item_id':item['id'],'product_id':item['product_id'],'product_name_snapshot':item['product_name_snapshot'],'quantity':qty,'unit_price':item['unit_price'],'refund_amount':refund};
        await txn.insert('sale_return_items',row);
        payloadItems.add({'sale_item_id':item['id'],'product_id':item['product_id'],'product_name_snapshot':item['product_name_snapshot'],'quantity':qty,'unit_price':item['unit_price'],'refund_amount':refund});
        final productId=item['product_id']?.toString();final movement=productId==null?null:movementByProduct[productId];
        if(productId!=null&&movement!=null){
          final products=await txn.query('products',where:'id=? AND business_id=?',whereArgs:[productId,businessId],limit:1);
          if(products.isNotEmpty&&(products.first['track_stock'] as num? ?? 1)!=0){
            await txn.rawUpdate('UPDATE products SET quantity=quantity+?,updated_at=?,sync_state=? WHERE id=? AND business_id=?',[qty,now,'pending',productId,businessId]);
            await txn.insert('stock_movements',{'id':_uuid.v4(),'business_id':businessId,'warehouse_id':movement['warehouse_id'],'product_id':productId,'movement_type':'sale_return','quantity_delta':qty,'note':'Retour $number','occurred_at':now,'sync_state':'pending','source_type':'sale_return','source_id':returnId});
          }
        }
      }
      await txn.insert('sale_returns',{'id':returnId,'business_id':businessId,'sale_id':saleId,'return_number':number,'reason':reason.trim(),'refund_method':refundMethod,'refund_amount':totalRefund,'status':'completed','returned_at':now,'created_at':now,'sync_state':'pending'});
      final payload={'id':returnId,'business_id':businessId,'sale_id':saleId,'return_number':number,'reason':reason.trim(),'refund_method':refundMethod,'refund_amount':totalRefund,'returned_at':now,'items':payloadItems};
      await txn.insert('outbox',{'id':returnId,'business_id':businessId,'entity_type':'sale_return','entity_id':returnId,'operation':'create','payload':jsonEncode(payload),'created_at':now,'attempts':0,'status':'queued'});
      final allReturnable=await txn.rawQuery('SELECT si.quantity,COALESCE((SELECT SUM(ri.quantity) FROM sale_return_items ri WHERE ri.sale_item_id=si.id),0) AS returned FROM sale_items si WHERE si.sale_id=?',[saleId]);
      if(allReturnable.isNotEmpty&&allReturnable.every((r)=>(r['returned'] as num)>=(r['quantity'] as num)-1e-8))await txn.update('sales',{'status':'returned'},where:'id=?',whereArgs:[saleId]);
    });
  }
}
