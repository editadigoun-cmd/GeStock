import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../local/gestock_database.dart';
String defaultCurrencyForCountry(String countryCode) => switch (countryCode) {
  'FR' => 'EUR', 'US' => 'USD', 'GB' => 'GBP', 'CM' => 'XAF', 'NG' => 'NGN', 'GH' => 'GHS',
  _ => 'XOF',
};

String defaultTimezoneForCountry(String countryCode) => switch (countryCode) {
  'BJ' => 'Africa/Porto-Novo', 'TG' => 'Africa/Lome', 'CI' => 'Africa/Abidjan',
  'SN' => 'Africa/Dakar', 'CM' => 'Africa/Douala', 'NG' => 'Africa/Lagos', 'GH' => 'Africa/Accra',
  'FR' => 'Europe/Paris', 'GB' => 'Europe/London', 'US' => 'America/New_York', _ => 'UTC',
};
class BusinessRepository {
 BusinessRepository(this.db);
 final GeStockDatabase db;final _uuid=const Uuid();
 Future<List<Map<String,Object?>>> list()async{final d=await db.database;return d.query('businesses',orderBy:'created_at DESC');}
 Future<Map<String,Object?>?> active()async{
  final d=await db.database;final setting=await d.query('app_settings',where:'key = ?',whereArgs:['active_business_id'],limit:1);
  if(setting.isNotEmpty){final rows=await d.query('businesses',where:'id = ?',whereArgs:[setting.first['value']],limit:1);if(rows.isNotEmpty)return rows.first;}
  final rows=await d.query('businesses',orderBy:'created_at DESC',limit:1);return rows.isEmpty?null:rows.first;
 }
 Future<void> setActive(String id)async{final d=await db.database;await d.insert('app_settings',{'key':'active_business_id','value':id},conflictAlgorithm:ConflictAlgorithm.replace);}
 Future<void> create({required String name,required String type,required String country,required String currency})async{
  final d=await db.database;final id=_uuid.v4();final warehouseId=_uuid.v4();final now=DateTime.now().toUtc().toIso8601String();
  final zone=defaultTimezoneForCountry(country);
  final payload={'id':id,'name':name.trim(),'business_type':type,'country_code':country,'currency_code':currency,'timezone':zone,'default_warehouse_id':warehouseId};
  await d.transaction((txn)async{
   await txn.insert('businesses',{...payload,'created_at':now,'sync_state':'pending'});
   await txn.insert('warehouses',{'id':warehouseId,'business_id':id,'name':'Dépôt principal','is_default':1,'created_at':now});
   await txn.insert('app_settings',{'key':'active_business_id','value':id},conflictAlgorithm:ConflictAlgorithm.replace);
   await txn.insert('outbox',{'id':_uuid.v4(),'business_id':id,'entity_type':'business','entity_id':id,'operation':'create','payload':jsonEncode(payload),'created_at':now});
  });
 }
}
