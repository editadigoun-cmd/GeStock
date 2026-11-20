import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';
import 'auth_repository.dart';

class ExpenseRepository {
  ExpenseRepository(this.db,this.auth,{Dio? dio}) : _dio=dio??Dio(BaseOptions(baseUrl:const String.fromEnvironment('GESTOCK_API_URL',defaultValue:'https://gestock-api.ccds22431.workers.dev'),headers:{'Content-Type':'application/json'}));
  final GeStockDatabase db;final AuthRepository auth;final Dio _dio;final _uuid=const Uuid();
  Future<List<Map<String,Object?>>> list(String businessId)async{final d=await db.database;return d.query('expenses',where:'business_id=?',whereArgs:[businessId],orderBy:'paid_at DESC');}
  Future<void> pullCloud(String businessId)async{
    final token=await auth.getAccessToken();final r=await _dio.get('/v1/expenses',queryParameters:{'business_id':businessId},options:Options(headers:{'Authorization':'Bearer $token'}));
    if(r.data is! Map||r.data['data'] is! List)throw StateError('Réponse dépenses invalide.');
    final d=await db.database;final now=DateTime.now().toUtc().toIso8601String();
    await d.transaction((txn)async{for(final raw in (r.data['data'] as List).whereType<Map>()){
      final x=Map<String,Object?>.from(raw);final id=x['id']?.toString();if(id==null)continue;
      final pending=await txn.query('outbox',where:"entity_type='expense' AND entity_id=? AND status IN ('queued','failed','conflict')",whereArgs:[id],limit:1);if(pending.isNotEmpty)continue;
      final local=await txn.query('expenses',where:'id=?',whereArgs:[id],limit:1);
      final values={'id':id,'business_id':businessId,'category':x['category']??'','description':x['description']??'','amount':x['amount']??0,'currency_code':x['currency_code']??'XOF','paid_at':x['paid_at']??now,'payment_method':x['payment_method'],'created_at':x['created_at']??now,'sync_state':'synced'};
      if(local.isEmpty)await txn.insert('expenses',values);else await txn.update('expenses',values,where:'id=?',whereArgs:[id]);
    }});
  }
  Future<void> create({required String businessId,required String category,required String description,required double amount,required String currencyCode,String paymentMethod=''})async{
    if(category.trim().isEmpty||description.trim().isEmpty||!amount.isFinite||amount<=0)throw ArgumentError('Catégorie, description et montant obligatoire.');
    final d=await db.database;final id=_uuid.v4();final now=DateTime.now().toUtc().toIso8601String();
    final payload={'id':id,'business_id':businessId,'category':category.trim(),'description':description.trim(),'amount':amount,'currency_code':currencyCode,'paid_at':now,'payment_method':paymentMethod.trim().isEmpty?null:paymentMethod.trim(),'created_at':now};
    await d.transaction((txn)async{
      await txn.insert('expenses',{...payload,'sync_state':'pending'});
      await txn.insert('outbox',{'id':id,'business_id':businessId,'entity_type':'expense','entity_id':id,'operation':'create','payload':jsonEncode(payload),'created_at':now,'attempts':0,'status':'queued'});
    });
  }
}
