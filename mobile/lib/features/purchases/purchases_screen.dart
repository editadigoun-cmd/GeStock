import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});
  @override ConsumerState<PurchasesScreen> createState()=>_PurchasesScreenState();
}
class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  bool busy=false; final Set<String> pulled={};
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achats & réceptions')),
      body: FutureBuilder<Map<String,Object?>?>(
        future: ref.read(businessRepositoryProvider).active(),
        builder:(context,businessSnap){
          if(businessSnap.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
          final business=businessSnap.data;
          if(business==null)return const Center(child:Text('Créez d’abord une entreprise.'));
          final businessId=business['id'].toString();
          if(pulled.add(businessId)){ref.read(purchaseRepositoryProvider).pullCloud(businessId).then((_) {if(mounted)setState((){});}).catchError((_){});}
          return FutureBuilder<List<Map<String,Object?>>>(
            future:ref.read(purchaseRepositoryProvider).list(businessId),
            builder:(context,snapshot){
              if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
              final rows=snapshot.data??[];
              if(rows.isEmpty)return _empty();
              return RefreshIndicator(onRefresh:()async{try{await ref.read(purchaseRepositoryProvider).pullCloud(businessId);}catch(_){}if(mounted)setState((){});},child:ListView.separated(
                padding:const EdgeInsets.fromLTRB(16,12,16,100),itemCount:rows.length,
                separatorBuilder:(_,__)=>const SizedBox(height:8),
                itemBuilder:(context,i){final p=rows[i];return Card(child:ListTile(
                  leading:const CircleAvatar(child:Icon(Icons.shopping_bag_outlined)),
                  title:Text(p['purchase_number'].toString(),style:const TextStyle(fontWeight:FontWeight.bold)),
                  subtitle:Text('${p['status']=='received'?'Réceptionnée':'En attente'} · ${p['total']} ${business['currency_code']}'),
                  trailing:Icon(p['sync_state']=='synced'?Icons.cloud_done_outlined:Icons.cloud_upload_outlined),
                  onTap:()=>_details(p),
                ));}
              ));
            },
          );
        },
      ),
      floatingActionButton:FloatingActionButton.extended(onPressed:busy?null:()=>_newPurchase(),icon:const Icon(Icons.add),label:const Text('Nouvelle réception')),
    );
  }
  Widget _empty()=>const Center(child:Padding(padding:EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.shopping_bag_outlined,size:52),SizedBox(height:12),Text('Aucun achat enregistré',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),Text('Enregistrez une réception pour augmenter automatiquement le stock.',textAlign:TextAlign.center)])));

  Future<void> _newPurchase() async {
    final business=await ref.read(businessRepositoryProvider).active();if(!mounted||business==null)return;
    final businessId=business['id'].toString();final db=await ref.read(databaseProvider).database;
    final warehouses=await db.query('warehouses',where:'business_id=? AND is_default=1',whereArgs:[businessId],limit:1);
    if(warehouses.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Dépôt principal introuvable.')));return;}
    final products=await db.query('products',where:'business_id=?',whereArgs:[businessId],orderBy:'name COLLATE NOCASE');
    final suppliers=await ref.read(supplierRepositoryProvider).list(businessId);
    if(products.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Ajoutez d’abord des produits au catalogue.')));return;}
    String? supplierId;final lines=<Map<String,Object?>>[];
    void addLine(){lines.add({'product_id':null,'quantity':TextEditingController(text:'1'),'unit_cost':TextEditingController(text:'0')});}
    addLine();
    final confirmed=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,backgroundColor:Colors.transparent,builder:(sheetContext)=>StatefulBuilder(builder:(sheetContext,setSheetState)=>Padding(
      padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(sheetContext).bottom),
      child:Container(padding:const EdgeInsets.all(18),decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Nouvelle réception',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
        DropdownButtonFormField<String?>(value:supplierId,decoration:const InputDecoration(labelText:'Fournisseur (facultatif)'),items:[const DropdownMenuItem<String?>(value:null,child:Text('Sans fournisseur')), ...suppliers.map((s)=>DropdownMenuItem<String?>(value:s['id'].toString(),child:Text(s['name'].toString())))],onChanged:(v)=>setSheetState(()=>supplierId=v)),
        const SizedBox(height:8),
        ...lines.asMap().entries.map((entry){final index=entry.key;final line=entry.value;return Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(children:[
          DropdownButtonFormField<String>(value:line['product_id'] as String?,decoration:InputDecoration(labelText:'Produit ${index+1}'),items:products.map((p)=>DropdownMenuItem(value:p['id'].toString(),child:Text(p['name'].toString(),overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setSheetState(()=>line['product_id']=v)),
          Row(children:[Expanded(child:TextField(controller:line['quantity'] as TextEditingController,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantité'))),const SizedBox(width:12),Expanded(child:TextField(controller:line['unit_cost'] as TextEditingController,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Coût unitaire'))),IconButton(icon:const Icon(Icons.delete_outline),onPressed:lines.length<=1?null:()=>setSheetState(()=>lines.removeAt(index)))]),
        ])));
        }),
        TextButton.icon(onPressed:()=>setSheetState(addLine),icon:const Icon(Icons.add),label:const Text('Ajouter un produit')),
        const SizedBox(height:8),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(sheetContext,true),child:const Text('Valider la réception'))),
      ])))),
    ));
    if(confirmed==true){
      try{
        final parsed=lines.map((l)=>{'product_id':l['product_id'],'quantity':double.tryParse((l['quantity'] as TextEditingController).text.replaceAll(',','.'))??0,'unit_cost':double.tryParse((l['unit_cost'] as TextEditingController).text.replaceAll(',','.'))??0}).toList();
        setState(()=>busy=true);
        await ref.read(purchaseRepositoryProvider).receive(businessId:businessId,warehouseId:warehouses.first['id'].toString(),currencyCode:business['currency_code'].toString(),supplierId:supplierId,items:parsed);
        try{await ref.read(syncServiceProvider).syncPending();}catch(_){}
        if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Réception enregistrée et stock mis à jour.')));}
      }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Bad state: ',''))));}
      finally{if(mounted)setState(()=>busy=false);}
    }
    for(final line in lines){(line['quantity'] as TextEditingController).dispose();(line['unit_cost'] as TextEditingController).dispose();}
  }
  Future<void> _details(Map<String,Object?> purchase)async {
    final items=await ref.read(purchaseRepositoryProvider).items(purchase['id'].toString());if(!mounted)return;
    showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text(purchase['purchase_number'].toString()),content:Column(mainAxisSize:MainAxisSize.min,children:items.map((i)=>ListTile(title:Text(i['product_name_snapshot'].toString()),subtitle:Text('${i['quantity']} × ${i['unit_cost']}'),trailing:Text(i['line_total'].toString()))).toList()),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Fermer'))]));
  }
}
