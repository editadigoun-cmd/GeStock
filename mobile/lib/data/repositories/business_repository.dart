import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';
class BusinessRepository {
 BusinessRepository(this.db);
 final GeStockDatabase db; final _uuid=const Uuid();
 Future<List<Map<String,Object?>>> list()async{final d=await db.database;return d.query('businesses',orderBy:'created_at DESC');}
 Future<Map<String,Object?>?> active()async{
  final d=await db.database;final setting=await d.query('app_settings',where:'key = ?',whereArgs:['active_business_id'],limit:1);
  if(setting.isNotEmpty){final id=setting.first['value'];final rows=await d.query('businesses',where:'id = ?',whereArgs:[id],limit:1);if(rows.isNotEmpty)return rows.first;}
  final rows=await d.query('businesses',orderBy:'created_at DESC',limit:1);return rows.isEmpty?null:rows.first;
 }
 Future<void> setActive(String id)async{final d=await db.database;await d.insert('app_settings',{'key':'active_business_id','value':id},conflictAlgorithm:ConflictAlgorithm.replace);}
 Future<void> create({required String name,required String type,required String country,required String currency})async{
  final d=await db.database;final id=_uuid.v4();final now=DateTime.now().toUtc().toIso8601String();
  final zone=switch(country){'BJ'=>'Africa/Porto-Novo','TG'=>'Africa/Lome','CI'=>'Africa/Abidjan','SN'=>'Africa/Dakar','CM'=>'Africa/Douala','FR'=>'Europe/Paris',_=>'UTC'};
  final payload={'id':id,'name':name.trim(),'business_type':type,'country_code':country,'currency_code':currency};
  await d.transaction((txn)async{
   await txn.insert('businesses',{...payload,'timezone':zone,'created_at':now,'sync_state':'pending'});
   await txn.insert('app_settings',{'key':'active_business_id','value':id},conflictAlgorithm:ConflictAlgorithm.replace);
   await txn.insert('outbox',{'id':_uuid.v4(),'business_id':id,'entity_type':'business','entity_id':id,'operation':'create','payload':jsonEncode(payload),'created_at':now});
  });
 }
}
