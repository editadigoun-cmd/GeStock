import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
 const ExpensesScreen({super.key});
 @override ConsumerState<ExpensesScreen> createState()=>_ExpensesScreenState();
}
class _ExpensesScreenState extends ConsumerState<ExpensesScreen>{
 final Set<String> pulled={};bool busy=false;
 static const categories=['Transport','Loyer','Électricité','Eau','Internet','Salaires','Fournitures','Maintenance','Marketing','Autres'];
 static const methods=['Espèces','Mobile Money','Carte','Virement','Autre'];
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Dépenses')),
  body:FutureBuilder<Map<String,Object?>?>(future:ref.read(businessRepositoryProvider).active(),builder:(context,b){
   if(b.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
   final business=b.data;if(business==null)return const Center(child:Text('Créez d’abord une entreprise.'));
   final id=business['id'].toString();
   if(pulled.add(id)){ref.read(expenseRepositoryProvider).pullCloud(id).then((_) {if(mounted)setState((){});}).catchError((_){});}
   return FutureBuilder<List<Map<String,Object?>>>(future:ref.read(expenseRepositoryProvider).list(id),builder:(context,s){
    if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
    final rows=s.data??[];
    if(rows.isEmpty)return const Center(child:Text('Aucune dépense enregistrée.'));
    final total=rows.fold<double>(0,(sum,x)=>sum+((x['amount'] as num?)?.toDouble()??0));
    return Column(children:[
      Padding(padding:const EdgeInsets.all(16),child:Card(child:ListTile(title:const Text('Total des dépenses enregistrées'),subtitle:Text('${rows.length} opérations'),trailing:Text('$total ${business['currency_code']}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))))),
      Expanded(child:RefreshIndicator(onRefresh:()async{try{await ref.read(expenseRepositoryProvider).pullCloud(id);}catch(_){}if(mounted)setState((){});},child:ListView.separated(padding:const EdgeInsets.symmetric(horizontal:16),itemCount:rows.length,separatorBuilder:(_,__)=>const Divider(),itemBuilder:(ctx,i){final x=rows[i];return ListTile(leading:const CircleAvatar(child:Icon(Icons.receipt_long_outlined)),title:Text(x['description'].toString()),subtitle:Text('${x['category']} · ${x['paid_at']}'),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${x['amount']} ${business['currency_code']}',style:const TextStyle(fontWeight:FontWeight.bold)),Icon(x['sync_state']=='synced'?Icons.cloud_done_outlined:Icons.cloud_upload_outlined,size:16)]));}))
    ]);
   });
  }),
  floatingActionButton:FloatingActionButton.extended(onPressed:busy?null:()=>_add(),icon:const Icon(Icons.add),label:const Text('Ajouter')),
 );
 Future<void> _add()async{
  final business=await ref.read(businessRepositoryProvider).active();if(!mounted||business==null)return;
  final category=TextEditingController(text:categories.first);final description=TextEditingController();final amount=TextEditingController();final method=TextEditingController(text:methods.first);
  final result=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,builder:(ctx)=>Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(ctx).bottom),child:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
   const Text('Nouvelle dépense',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
   DropdownButtonFormField<String>(value:category.text,decoration:const InputDecoration(labelText:'Catégorie'),items:categories.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>category.text=v??categories.first),
   TextField(controller:description,decoration:const InputDecoration(labelText:'Description')),
   TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Montant')),
   DropdownButtonFormField<String>(value:method.text,decoration:const InputDecoration(labelText:'Mode de paiement'),items:methods.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>method.text=v??methods.first),
   const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Enregistrer la dépense'))),
  ])))));
  if(result==true){
   try{final value=double.tryParse(amount.text.replaceAll(',','.'))??0;setState(()=>busy=true);await ref.read(expenseRepositoryProvider).create(businessId:business['id'].toString(),category:category.text,description:description.text,amount:value,currencyCode:business['currency_code'].toString(),paymentMethod:method.text);try{await ref.read(syncServiceProvider).syncPending();}catch(_){}if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Dépense enregistrée.')));}}
   catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Bad state: ',''))));}
   finally{if(mounted)setState(()=>busy=false);}
  }
  category.dispose();description.dispose();amount.dispose();method.dispose();
 }
}
