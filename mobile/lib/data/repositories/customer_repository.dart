import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';

class CustomerRepository {
  CustomerRepository(this.db);
  final GeStockDatabase db;
  final _uuid = const Uuid();

  Future<List<Map<String,Object?>>> list(String businessId,{String query=''}) async {
    final d=await db.database;
    final q=query.trim();
    if(q.isEmpty) return d.query('customers',where:'business_id=?',whereArgs:[businessId],orderBy:'name COLLATE NOCASE');
    return d.query('customers',where:'business_id=? AND (name LIKE ? OR phone LIKE ? OR email LIKE ?)',whereArgs:[businessId,'%$q%','%$q%','%$q%'],orderBy:'name COLLATE NOCASE');
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
