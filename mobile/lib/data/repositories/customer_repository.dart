import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'auth_repository.dart';
import '../local/gestock_database.dart';

class CustomerRepository {
  CustomerRepository(this.db, this.auth, {Dio? dio}) : _dio = dio ?? Dio(BaseOptions(baseUrl: const String.fromEnvironment('GESTOCK_API_URL', defaultValue: 'https://gestock-api.ccds22431.workers.dev'), headers: {'Content-Type':'application/json'}));
  final GeStockDatabase db;
  final AuthRepository auth;
  final Dio _dio;
  final _uuid = const Uuid();

  Future<List<Map<String,Object?>>> list(String businessId,{String query=''}) async {
    final d=await db.database;
    final q=query.trim();
    if(q.isEmpty) return d.query('customers',where:'business_id=?',whereArgs:[businessId],orderBy:'name COLLATE NOCASE');
    return d.query('customers',where:'business_id=? AND (name LIKE ? OR phone LIKE ? OR email LIKE ?)',whereArgs:[businessId,'%$q%','%$q%','%$q%'],orderBy:'name COLLATE NOCASE');
  }


  Future<void> pullCloud(String businessId) async {
    final token=await auth.getAccessToken();
    final response=await _dio.get('/v1/customers',queryParameters:{'business_id':businessId},options:Options(headers:{'Authorization':'Bearer $token'}));
    final data=response.data;
    if(data is! Map || data['data'] is! List) throw StateError('Réponse clients invalide.');
    final dbi=await db.database; final now=DateTime.now().toUtc().toIso8601String();
    await dbi.transaction((txn) async {
      for(final raw in (data['data'] as List).whereType<Map>()) {
        final row=Map<String,Object?>.from(raw); final customerId=row['id']?.toString(); if(customerId==null) continue;
        final queued=await txn.query('outbox',where:"entity_type='customer' AND entity_id=? AND status IN ('queued','failed','conflict')",whereArgs:[customerId],limit:1);
        if(queued.isNotEmpty) continue;
        final pendingSale = await txn.rawQuery("SELECT COUNT(*) AS count FROM outbox WHERE entity_type='sale' AND status IN ('queued','failed','conflict') AND payload LIKE ?", ['%"customer_id":"$customerId"%']);
        if(((pendingSale.first['count'] as num?)?.toInt()??0)>0) continue;
        final pendingPayment=await txn.rawQuery("SELECT COUNT(*) AS count FROM outbox WHERE entity_type='customer_payment' AND status IN ('queued','failed','conflict') AND payload LIKE ?", ['%\"customer_id\":\"$customerId\"%']);
        if(((pendingPayment.first['count'] as num?)?.toInt()??0)>0) continue;
        final local=await txn.query('customers',where:'id=?',whereArgs:[customerId],limit:1);
        final values={'id':customerId,'business_id':businessId,'name':row['name']??'','phone':row['phone'],'email':row['email'],'address':row['address'],'notes':row['notes'],'balance_due':row['balance_due']??0,'created_at':row['created_at']??now,'updated_at':row['updated_at']??now,'sync_state':'synced'};
        if(local.isEmpty) await txn.insert('customers',values); else await txn.update('customers',values,where:'id=?',whereArgs:[customerId]);
      }
    });
  }

  Future<void> create({required String businessId,required String name,String phone='',String email='',String address='',String notes=''}) async {
    if(name.trim().isEmpty) throw ArgumentError('Le nom du client est obligatoire.');
    final d=await db.database; final id=_uuid.v4(); final now=DateTime.now().toUtc().toIso8601String();
    final payload={'id':id,'business_id':businessId,'name':name.trim(),'phone':phone.trim().isEmpty?null:phone.trim(),'email':email.trim().isEmpty?null:email.trim(),'address':address.trim().isEmpty?null:address.trim(),'notes':notes.trim().isEmpty?null:notes.trim(),'balance_due':0,'created_at':now,'updated_at':now};
    await d.transaction((txn) async {
      await txn.insert('customers',{...payload,'sync_state':'pending'});
      await txn.insert('outbox',{'id':id,'business_id':businessId,'entity_type':'customer','entity_id':id,'operation':'upsert','payload':jsonEncode(payload),'created_at':now,'attempts':0,'status':'queued'});
    });
  }

  Future<void> update({required String businessId,required String customerId,required String name,String phone='',String email='',String address='',String notes=''}) async {
    if(name.trim().isEmpty) throw ArgumentError('Le nom du client est obligatoire.');
    final d=await db.database; final now=DateTime.now().toUtc().toIso8601String();
    final rows=await d.query('customers',where:'id=? AND business_id=?',whereArgs:[customerId,businessId],limit:1);
    if(rows.isEmpty) throw StateError('Client introuvable.');
    final payload={'id':customerId,'business_id':businessId,'name':name.trim(),'phone':phone.trim().isEmpty?null:phone.trim(),'email':email.trim().isEmpty?null:email.trim(),'address':address.trim().isEmpty?null:address.trim(),'notes':notes.trim().isEmpty?null:notes.trim(),'balance_due':rows.first['balance_due']??0,'created_at':rows.first['created_at'],'updated_at':now};
    await d.transaction((txn) async {
      await txn.update('customers',{...payload,'sync_state':'pending'},where:'id=? AND business_id=?',whereArgs:[customerId,businessId]);
      final pending=await txn.query('outbox',where:"entity_type='customer' AND entity_id=? AND status IN ('queued','failed','conflict')",whereArgs:[customerId],orderBy:'created_at DESC',limit:1);
      if(pending.isNotEmpty) {
        await txn.update('outbox',{'payload':jsonEncode(payload),'created_at':now,'status':'queued','attempts':0},where:'id=?',whereArgs:[pending.first['id']]);
      } else {
        await txn.insert('outbox',{'id':_uuid.v4(),'business_id':businessId,'entity_type':'customer','entity_id':customerId,'operation':'upsert','payload':jsonEncode(payload),'created_at':now,'attempts':0,'status':'queued'});
      }
    });
  }
}
