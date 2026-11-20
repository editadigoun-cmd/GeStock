import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';

class CustomersScreen extends ConsumerStatefulWidget { const CustomersScreen({super.key}); @override ConsumerState<CustomersScreen> createState()=>_CustomersScreenState(); }
class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String query='';
  bool busy=false;
  final Set<String> pulledBusinesses={};
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Clients')),
    body:FutureBuilder<Map<String,Object?>?>(
      future:ref.read(businessRepositoryProvider).active(),
      builder:(context,businessSnapshot){
        if(businessSnapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
        final business=businessSnapshot.data;if(business==null)return const Center(child:Text('Créez d’abord une entreprise.'));
        final businessId=business['id'] as String;
        if(!pulledBusinesses.contains(businessId)){pulledBusinesses.add(businessId);ref.read(customerRepositoryProvider).pullCloud(businessId).then((_) {if(mounted)setState((){});}).catchError((_){});}
        return Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(16,10,16,8),child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Rechercher nom, téléphone, email'),onChanged:(v)=>setState(()=>query=v))),
          Expanded(child:FutureBuilder<List<Map<String,Object?>>>(
            future:ref.read(customerRepositoryProvider).list(businessId,query:query),
            builder:(context,snapshot){
              if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
              final rows=snapshot.data??[];
              if(rows.isEmpty)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(query.isEmpty?'Aucun client. Ajoutez votre premier client.':'Aucun résultat pour « $query ».',textAlign:TextAlign.center)));
              return ListView.separated(padding:const EdgeInsets.fromLTRB(16,4,16,100),itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){
                final c=rows[i];return Card(child:ListTile(
                  leading:CircleAvatar(backgroundColor:GeStockColors.emerald.withValues(alpha:.12),child:const Icon(Icons.person_outline,color:GeStockColors.deepEmerald)),
                  title:Text(c['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
                  subtitle:Text([c['phone'],c['email'],c['address'],((c['balance_due'] as num?)?.toDouble()??0)>0?'Dette : ${(c['balance_due'] as num).toStringAsFixed(0)} ${business['currency_code']}':null].where((v)=>v!=null&&v.toString().trim().isNotEmpty).join(' · ')),
                  isThreeLine:false,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(c['sync_state']=='synced'?Icons.cloud_done_outlined:Icons.cloud_upload_outlined,color:c['sync_state']=='synced'?GeStockColors.deepEmerald:GeStockColors.amber),
                    if (((c['balance_due'] as num?)?.toDouble()??0)>0) IconButton(tooltip:'Encaisser une dette',icon:const Icon(Icons.payments_outlined,color:GeStockColors.deepEmerald),onPressed:()=>_collect(businessId,c)),
                  ]),
                  onTap:()=>_edit(businessId,c),
                ));
              });
            })),
        ]);
      }),
    floatingActionButton:FloatingActionButton.extended(onPressed:busy?null:()=>_edit(null,null),icon:const Icon(Icons.person_add_alt_1),label:const Text('Nouveau client')),
  );

  Future<void> _collect(String businessId,Map<String,Object?> customer) async {
    final balance=(customer['balance_due'] as num?)?.toDouble()??0;
    if(balance<=0)return;
    final amount=TextEditingController(text:balance.toStringAsFixed(0));
    String method='cash';final note=TextEditingController();
    final result=await showDialog<Map<String,Object?>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
      title:Text('Encaissement · ${customer['name']}'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('Dette restante : ${balance.toStringAsFixed(0)}'),
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Montant reçu')),
        DropdownButtonFormField<String>(value:method,decoration:const InputDecoration(labelText:'Mode de paiement'),items:const ['cash','mobile_money','card','bank_transfer','other'].map((m)=>DropdownMenuItem(value:m,child:Text({'cash':'Espèces','mobile_money':'Mobile Money','card':'Carte','bank_transfer':'Virement','other':'Autre'}[m]!))).toList(),onChanged:(v)=>setDialog(()=>method=v??'cash')),
        TextField(controller:note,decoration:const InputDecoration(labelText:'Note (facultatif)')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(ctx,{'amount':double.tryParse(amount.text.replaceAll(',','.'))??0,'method':method,'note':note.text}),child:const Text('Enregistrer'))],
    )));
    if(result==null)return;
    final value=result['amount'] as double;
    if(value<=0||value>balance){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Montant invalide ou supérieur à la dette.')));return;}
    setState(()=>busy=true);
    try{
      await ref.read(customerPaymentRepositoryProvider).collect(businessId:businessId,customerId:customer['id'].toString(),amount:value,paymentMethod:result['method'].toString(),note:result['note'].toString());
      try{await ref.read(syncServiceProvider).syncPending();}catch(_){}
      await ref.read(customerRepositoryProvider).pullCloud(businessId);
      if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Encaissement enregistré.')));}
    }catch(error){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error.toString().replaceFirst('Bad state: ',''))));}
    finally{if(mounted)setState(()=>busy=false);}
    amount.dispose();note.dispose();
  }

  Future<void> _edit(String? businessId,Map<String,Object?>? customer) async {
    if(busy)return;
    final business=await ref.read(businessRepositoryProvider).active();
    if(business==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Créez d’abord une entreprise.')));return;}
    final id=business['id'] as String;
    final name=TextEditingController(text:customer?['name']?.toString()??'');
    final phone=TextEditingController(text:customer?['phone']?.toString()??'');
    final email=TextEditingController(text:customer?['email']?.toString()??'');
    final address=TextEditingController(text:customer?['address']?.toString()??'');
    final notes=TextEditingController(text:customer?['notes']?.toString()??'');
    final ok=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,backgroundColor:Colors.transparent,builder:(ctx)=>Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(ctx).bottom),child:Container(padding:const EdgeInsets.all(22),decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(26))),child:Wrap(runSpacing:12,children:[
      Text(customer==null?'Nouveau client':'Modifier le client',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
      TextField(controller:name,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Nom *')),
      TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Téléphone')),
      TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email')),
      TextField(controller:address,decoration:const InputDecoration(labelText:'Adresse')),
      TextField(controller:notes,maxLines:2,decoration:const InputDecoration(labelText:'Notes')),
      SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(customer==null?'Créer le client':'Enregistrer'))),
    ]))));
    if(ok==true&&name.text.trim().isNotEmpty){
      setState(()=>busy=true);
      try{
        final repo=ref.read(customerRepositoryProvider);
        if(customer==null)await repo.create(businessId:id,name:name.text,phone:phone.text,email:email.text,address:address.text,notes:notes.text);
        else await repo.update(businessId:id,customerId:customer['id'].toString(),name:name.text,phone:phone.text,email:email.text,address:address.text,notes:notes.text);
        try{await ref.read(syncServiceProvider).syncPending();}catch(_){}
        if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Client enregistré.')));}
      }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Invalid argument(s): ',''))));}
      finally{if(mounted)setState(()=>busy=false);}
    }
    for(final controller in [name,phone,email,address,notes])controller.dispose();
  }
}
