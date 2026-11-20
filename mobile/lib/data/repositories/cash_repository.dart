import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../local/gestock_database.dart';

class CashRepository {
  CashRepository(this.db);
  final GeStockDatabase db;final _uuid=const Uuid();

  Future<Map<String,Object?>?> activeSession(String businessId)async{final d=await db.database;final rows=await d.query('cash_sessions',where:"business_id=? AND status='open'",whereArgs:[businessId],orderBy:'opened_at DESC',limit:1);return rows.isEmpty?null:rows.first;}

  Future<List<Map<String,Object?>>> list(String businessId)async{final d=await db.database;return d.query('cash_sessions',where:'business_id=?',whereArgs:[businessId],orderBy:'opened_at DESC',limit:100);}

  Future<Map<String,double>> summary(String businessId,String sessionId)async{
    final d=await db.database;final sessionRows=await d.query('cash_sessions',where:'id=?',whereArgs:[sessionId],limit:1);if(sessionRows.isEmpty)throw StateError('Session de caisse introuvable.');
    final s=sessionRows.first;final start=s['opened_at'].toString();final end=(s['closed_at']??DateTime.now().toUtc().toIso8601String()).toString();
    Future<double> sum(String sql,List<Object?> args)async{final r=await d.rawQuery(sql,args);return (r.first['amount'] as num?)?.toDouble()??0;}
    final salesCash=await sum("SELECT COALESCE(SUM(sp.amount),0) AS amount FROM sale_payments sp JOIN sales s ON s.id=sp.sale_id WHERE s.business_id=? AND sp.payment_method IN ('cash','Espèces','especes','espèces') AND sp.status='confirmed' AND COALESCE(sp.paid_at,s.sold_at)>=? AND COALESCE(sp.paid_at,s.sold_at)<=?",[businessId,start,end]);
    final debtCash=await sum("SELECT COALESCE(SUM(amount),0) AS amount FROM customer_payments WHERE business_id=? AND payment_method IN ('cash','Espèces','especes','espèces') AND paid_at>=? AND paid_at<=?",[businessId,start,end]);
    final expenseCash=await sum("SELECT COALESCE(SUM(amount),0) AS amount FROM expenses WHERE business_id=? AND payment_method IN ('cash','Espèces','especes','espèces') AND paid_at>=? AND paid_at<=?",[businessId,start,end]);
    final refundCash=await sum("SELECT COALESCE(SUM(refund_amount),0) AS amount FROM sale_returns WHERE business_id=? AND refund_method IN ('cash','Espèces','especes','espèces') AND returned_at>=? AND returned_at<=?",[businessId,start,end]);
    final opening=(s['opening_amount'] as num).toDouble();final expected=opening+salesCash+debtCash-expenseCash-refundCash;
    return {'opening':opening,'cash_sales':salesCash,'cash_debt_collections':debtCash,'cash_expenses':expenseCash,'cash_refunds':refundCash,'expected':expected};
  }

  Future<void> open({required String businessId,required double openingAmount})async{
    if(!openingAmount.isFinite||openingAmount<0)throw ArgumentError('Montant initial invalide.');
    final d=await db.database;final active=await activeSession(businessId);if(active!=null)throw StateError('Une caisse est déjà ouverte.');
    final now=DateTime.now().toUtc().toIso8601String();final registerRows=await d.query('cash_registers',where:'business_id=? AND name=?',whereArgs:[businessId,'Caisse principale'],limit:1);
    final registerId=registerRows.isNotEmpty?registerRows.first['id'].toString():_uuid.v4();if(registerRows.isEmpty)await d.insert('cash_registers',{'id':registerId,'business_id':businessId,'name':'Caisse principale','is_active':1,'created_at':now});
    final id=_uuid.v4();final payload={'id':id,'business_id':businessId,'register_id':registerId,'name':'Caisse principale','opening_amount':openingAmount,'opened_at':now,'status':'open'};
    await d.transaction((txn)async{await txn.insert('cash_sessions',{...payload,'closed_by':null,'closing_amount':null,'expected_amount':null,'closed_at':null,'created_at':now,'updated_at':now,'sync_state':'pending'});await txn.insert('outbox',{'id':_uuid.v4(),'business_id':businessId,'entity_type':'cash_session','entity_id':id,'operation':'open','payload':jsonEncode(payload),'created_at':now,'attempts':0,'status':'queued'});});
  }

  Future<void> close({required String businessId,required String sessionId,required double closingAmount})async{
    if(!closingAmount.isFinite||closingAmount<0)throw ArgumentError('Montant réel invalide.');
    final d=await db.database;final rows=await d.query('cash_sessions',where:"id=? AND business_id=? AND status='open'",whereArgs:[sessionId,businessId],limit:1);if(rows.isEmpty)throw StateError('Aucune caisse ouverte.');
    final summary=await this.summary(businessId,sessionId);final now=DateTime.now().toUtc().toIso8601String();
    final payload={'id':sessionId,'business_id':businessId,'register_id':rows.first['register_id'],'closing_amount':closingAmount,'expected_amount':summary['expected'],'difference':difference,'closed_at':now,'status':'closed'};
    await d.transaction((txn)async{await txn.update('cash_sessions',{'closing_amount':closingAmount,'expected_amount':summary['expected'],'closed_at':now,'status':'closed','updated_at':now,'sync_state':'pending'},where:'id=?',whereArgs:[sessionId]);await txn.insert('outbox',{'id':_uuid.v4(),'business_id':businessId,'entity_type':'cash_session','entity_id':sessionId,'operation':'close','payload':jsonEncode(payload),'created_at':now,'attempts':0,'status':'queued'});});
  }
}
