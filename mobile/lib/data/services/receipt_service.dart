import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../local/gestock_database.dart';

class ReceiptService {
  static Future<void> printSaleReceipt({required BuildContext context, required GeStockDatabase database, required String businessId, required Map<String,Object?> sale}) async {
    final db = await database.database;
    final businessRows = await db.query('businesses', where: 'id = ?', whereArgs: [businessId], limit: 1);
    final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [sale['id']]);
    if (items.isEmpty) throw StateError('Détails de vente absents.');
    final business = businessRows.isNotEmpty ? businessRows.first : <String,Object?>{};
    final currency = sale['currency_code']?.toString() ?? business['currency_code']?.toString() ?? 'XOF';
    final paid = (sale['amount_paid'] as num?)?.toDouble() ?? 0;
    final total = (sale['total'] as num?)?.toDouble() ?? 0;
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.roll80.copyWith(marginLeft:5*PdfPageFormat.mm,marginRight:5*PdfPageFormat.mm,marginTop:5*PdfPageFormat.mm,marginBottom:5*PdfPageFormat.mm),build:(_) => pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
      pw.Center(child:pw.Text(business['name']?.toString()??'GeStock',style:pw.TextStyle(fontSize:16,fontWeight:pw.FontWeight.bold))),
      pw.Center(child:pw.Text('REÇU DE VENTE',style:pw.TextStyle(fontSize:10,fontWeight:pw.FontWeight.bold))),pw.Divider(),
      pw.Text('N° '+(sale['sale_number']?.toString()??''),style:const pw.TextStyle(fontSize:8)),
      pw.Text('Date : '+(DateTime.tryParse(sale['sold_at']?.toString()??'')?.toLocal().toString().substring(0,16)??''),style:const pw.TextStyle(fontSize:8)),
      pw.Text('Paiement : '+(sale['payment_method']?.toString()??''),style:const pw.TextStyle(fontSize:8)),pw.SizedBox(height:6),
      ...items.map((item){final q=(item['quantity'] as num).toDouble();final unit=(item['unit_price'] as num).toDouble();final line=(item['line_total'] as num).toDouble();return pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[pw.Text(item['product_name_snapshot']?.toString()??'Produit',style:pw.TextStyle(fontSize:8,fontWeight:pw.FontWeight.bold)),pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[pw.Text(q.toStringAsFixed(2)+' × '+unit.toStringAsFixed(0),style:const pw.TextStyle(fontSize:8)),pw.Text(line.toStringAsFixed(0)+' '+currency,style:const pw.TextStyle(fontSize:8))]),pw.SizedBox(height:3)]);}),pw.Divider(),
      pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[pw.Text('TOTAL',style:pw.TextStyle(fontSize:11,fontWeight:pw.FontWeight.bold)),pw.Text(total.toStringAsFixed(0)+' '+currency,style:pw.TextStyle(fontSize:11,fontWeight:pw.FontWeight.bold))]),
      pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[pw.Text('Payé',style:const pw.TextStyle(fontSize:8)),pw.Text(paid.toStringAsFixed(0)+' '+currency,style:const pw.TextStyle(fontSize:8))]),
      if(total>paid)pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[pw.Text('Reste dû',style:pw.TextStyle(fontSize:9,fontWeight:pw.FontWeight.bold)),pw.Text((total-paid).toStringAsFixed(0)+' '+currency,style:pw.TextStyle(fontSize:9,fontWeight:pw.FontWeight.bold))]),
      pw.SizedBox(height:8),pw.Center(child:pw.Text('Merci pour votre achat !',style:const pw.TextStyle(fontSize:8)))
    ])));
    await Printing.layoutPdf(onLayout:(_) async=>pdf.save(),name:'GeStock-'+(sale['sale_number']?.toString()??'recu')+'.pdf');
  }
}
