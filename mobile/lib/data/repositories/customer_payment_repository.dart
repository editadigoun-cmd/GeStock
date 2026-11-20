import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';
import 'auth_repository.dart';

class CustomerPaymentRepository {
  CustomerPaymentRepository(this.db,this.auth,{Dio? dio}) : _dio=dio??Dio(BaseOptions(baseUrl:const String.fromEnvironment('GESTOCK_API_URL',defaultValue:'https://gestock-api.ccds22431.workers.dev'),headers:{'Content-Type':'application/json'}));
  final GeStockDatabase db;final AuthRepository auth;final Dio _dio;final _uuid=const Uuid();
  Future<List<Map<String,Object?>>> list(String businessId,String customerId)async{final d=await db.database;return d.query('customer_payments',where:'business_id=? AND customer_id=?',whereArgs:[businessId,customerId],orderBy:'paid_at DESC');}
  Future<void> pullCloud(String businessId,String customerId)async{
    final token=await auth.getAccessToken();final response=await _dio.get('/v1/customer-payments',queryParameters:{'business_id':businessId,'customer_id':customerId},options:Options(headers:{'Authorization':'Bearer $token'}));
    if(response.data is! Map||response.data['data'] is! List)throw StateError('Historique des paiements invalide.');
    final d=await db.database;final now=DateTime.now().toUtc().toIso8601String();
    await d.transaction((txn)async{for(final raw in (response.data['data'] as List).whereType<Map>()){
      final row=Map<String,Object?>.from(raw);final id=row['id']?.toString();if(id==null)continue;
      final pending=await txn.query('outbox',where:"entity_type='customer_payment' AND entity_id=? AND status IN ('queued','failed','conflict')",whereArgs:[id],limit:1);if(pending.isNotEmpty)continue;
      final local=await txn.query('customer_payments',where:'id=?',whereArgs:[id],limit:1);
      final values={'id':id,'business_id':businessId,'customer_id':customerId,'amount':row['amount']??0,'payment_method':row['payment_method']??'cash','note':row['note'],'paid_at':row['paid_at']??now,'created_at':row['created_at']??now,'sync_state':'synced'};
      if(local.isEmpty)await txn.insert('customer_payments',values);else await txn.update('customer_payments',values,where:'id=?',whereArgs:[id]);
    }});
  }
  Future<void> collect({required String businessId,required String customerId,required double amount,required String paymentMethod,String note=''})async{
    if(!amount.isFinite||amount<=0)throw ArgumentError('Montant invalide.');
    if(!['cash','mobile_money','card','bank_transfer','other'].contains(paymentMethod))throw ArgumentError('Mode de paiement invalide.');
    final d=await db.database;final id=_uuid.v4();final now=DateTime.now().toUtc().toIso8601String();
    final customer=await d.query('customers',where:'id=? AND business_id=?',whereArgs:[customerId,businessId],limit:1);if(customer.isEmpty)throw StateError('Client introuvable.');
    final balance=(customer.first['balance_due'] as num?)?.toDouble()??0;if(amount>balance)throw StateError('Le paiement dépasse la dette restante.');
    final payload={'id':id,'business_id':businessId,'customer_id':customerId,'amount':amount,'payment_method':paymentMethod,'note':note.trim().isEmpty?null:note.trim(),'paid_at':now,'created_at':now};
    await d.transaction((txn)async{
      await txn.insert('customer_payments',{...payload,'sync_state':'pending'});
      await txn.rawUpdate('UPDATE customers SET balance_due=MAX(balance_due-?,0),updated_at=?,sync_state=? WHERE id=? AND business_id=?',[amount,now,'pending',customerId,businessId]);
      await txn.insert('outbox',{'id':id,'business_id':businessId,'entity_type':'customer_payment','entity_id':id,'operation':'create','payload':jsonEncode(payload),'created_at':now,'attempts':0,'status':'queued'});
    });
  }
}
