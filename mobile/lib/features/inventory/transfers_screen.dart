import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});
  @override ConsumerState<TransfersScreen> createState()=>_TransfersScreenState();
}
class _TransfersScreenState extends ConsumerState<TransfersScreen>{
  final Dio dio=Dio(BaseOptions(baseUrl:const String.fromEnvironment('GESTOCK_API_URL',defaultValue:'https://gestock-api.ccds22431.workers.dev'),headers:{'Content-Type':'application/json'}));
  bool loading=false,saving=false;
  String? error,sourceId,destinationId,selectedProductId;
  final qtyController=TextEditingController(text:'1');
  final noteController=TextEditingController();
  final Map<String,double> cart={};
  List<Map<String,Object?>> warehouses=[],levels=[],history=[],products=[];
  String? loadedBusiness;
  Future<Map<String,Object?>?>? businessFuture;
  @override void initState(){super.initState();businessFuture=ref.read(businessRepositoryProvider).active();}
  @override void dispose(){qtyController.dispose();noteController.dispose();super.dispose();}
  Future<String> token()async=>await ref.read(authRepositoryProvider).getAccessToken()??'';
  Future<void> load(String businessId)async{
    setState(()=>loading=true);
    try{
      final t=await token();
      final opts=Options(headers:{'Authorization':'Bearer '+t});
      final results=await Future.wait([
        dio.get('/v1/stock/warehouses',queryParameters:{'business_id':businessId},options:opts),
        dio.get('/v1/stock/levels',queryParameters:{'business_id':businessId},options:opts),
        dio.get('/v1/stock/transfers',queryParameters:{'business_id':businessId},options:opts),
        ref.read(productRepositoryProvider).list(businessId),
      ]);
      warehouses=(results[0].data['data'] as List).whereType<Map>().map((e)=>Map<String,Object?>.from(e)).toList();
      levels=(results[1].data['data'] as List).whereType<Map>().map((e)=>Map<String,Object?>.from(e)).toList();
      history=(results[2].data['data'] as List).whereType<Map>().map((e)=>Map<String,Object?>.from(e)).toList();
      products=results[3] as List<Map<String,Object?>>;
      sourceId??=warehouses.firstWhere((w)=>w['is_default']==1,orElse:()=>warehouses.isNotEmpty?warehouses.first:<String,Object?>{})['id']?.toString();
      if(destinationId==null&&warehouses.length>1)destinationId=warehouses.firstWhere((w)=>w['id']!=sourceId)['id']?.toString();
      if(sourceId==destinationId)destinationId=null;
      error=null;loadedBusiness=businessId;
    }catch(e){error=_error(e);}
    finally{if(mounted)setState(()=>loading=false);}
  }
  String _error(Object e){if(e is DioException){final data=e.response?.data;if(data is Map&&data['error']!=null)return data['error'].toString();return e.message??'Erreur réseau';}return e.toString().replaceFirst('Exception: ','');}
  double available(String productId){return levels.where((x)=>x['warehouse_id']==sourceId&&x['product_id']==productId).fold<double>(0,(sum,x)=>sum+((x['quantity'] as num?)?.toDouble()??0));}
  Future<void> addProduct()async{
    final id=selectedProductId,qty=double.tryParse(qtyController.text.replaceAll(',','.'));
    if(id==null||qty==null||!qty.isFinite||qty<=0){message('Choisissez un produit et une quantité valide.');return;}
    final next=(cart[id]??0)+qty;
    if(next>available(id)){message('Stock insuffisant dans le dépôt source. Disponible : '+available(id).toStringAsFixed(2));return;}
    setState(()=>cart[id]=next);
  }
  Future<void> createWarehouse()async{
    final c=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Nouveau dépôt'),content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(labelText:'Nom du dépôt')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('Créer'))]));
    c.dispose();if(name==null||name.trim().isEmpty)return;
    final b=await businessFuture; if(b==null)return;
    try{final t=await token();await dio.post('/v1/stock/warehouses',data:{'business_id':b['id'],'name':name},options:Options(headers:{'Authorization':'Bearer '+t}));await load(b['id'].toString());message('Dépôt créé.');}
    catch(e){message(_error(e));}
  }
  Future<void> submit()async{
    if(sourceId==null||destinationId==null||sourceId==destinationId||cart.isEmpty){message('Sélectionnez deux dépôts différents et ajoutez des produits.');return;}
    final b=await businessFuture;if(b==null)return;
    setState(()=>saving=true);
    try{
      final t=await token();
      final payload={'business_id':b['id'],'from_warehouse_id':sourceId,'to_warehouse_id':destinationId,'note':noteController.text.trim(),'items':cart.entries.map((e)=>{'product_id':e.key,'quantity':e.value}).toList()};
      final r=await dio.post('/v1/stock/transfers',data:payload,options:Options(headers:{'Authorization':'Bearer '+t}));
      try{await ref.read(syncServiceProvider).syncPending();}catch(_){}
      cart.clear();noteController.clear();await load(b['id'].toString());
      message('Transfert enregistré : '+(r.data['data']?['transferNumber']?.toString()??'stock mis à jour'));
    }catch(e){message(_error(e));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  void message(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  String warehouseName(String? id)=>warehouses.firstWhere((w)=>w['id']?.toString()==id,orElse:()=>{})['name']?.toString()??'Dépôt';
  String money(double n)=>n.toStringAsFixed(n%1==0?0:2);
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Transferts de stock'),actions:[IconButton(onPressed:loading?null:()=>createWarehouse(),tooltip:'Créer un dépôt',icon:const Icon(Icons.add_business_outlined)),IconButton(onPressed:loading?null:()=>businessFuture?.then((b){if(b!=null)load(b['id'].toString());}),icon:const Icon(Icons.refresh))]),body:FutureBuilder<Map<String,Object?>?>(future:businessFuture,builder:(context,snap){if(snap.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());final b=snap.data;if(b==null)return const Center(child:Text('Créez une entreprise avant de gérer les transferts.'));final businessId=b['id'].toString();if(loadedBusiness!=businessId&&!loading){WidgetsBinding.instance.addPostFrameCallback((_)=>load(businessId));}return loading&&warehouses.isEmpty?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
    const Card(child:Padding(padding:EdgeInsets.all(14),child:Text('Les transferts sont effectués en ligne et mettent à jour les stocks des deux dépôts.'))),
    if(error!=null)Card(color:Theme.of(context).colorScheme.errorContainer,child:Padding(padding:const EdgeInsets.all(12),child:Text(error!))),
    if(warehouses.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Aucun dépôt. Créez un dépôt pour commencer.'))),
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Origine et destination',style:TextStyle(fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      DropdownButtonFormField<String>(value:sourceId,decoration:const InputDecoration(labelText:'Dépôt source'),items:warehouses.map((w)=>DropdownMenuItem(value:w['id'].toString(),child:Text(w['name'].toString()))).toList(),onChanged:(v){setState(()=>sourceId=v);if(destinationId==v)setState(()=>destinationId=null);}),
      ),
      const SizedBox(height:8),
      DropdownButtonFormField<String>(value:destinationId,decoration:const InputDecoration(labelText:'Dépôt destination'),items:warehouses.where((w)=>w['id']!=sourceId).map((w)=>DropdownMenuItem(value:w['id'].toString(),child:Text(w['name'].toString()))).toList(),onChanged:(v)=>setState(()=>destinationId=v)),
    ]))),
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Ajouter des produits',style:TextStyle(fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      DropdownButtonFormField<String>(value:selectedProductId,decoration:const InputDecoration(labelText:'Produit'),items:products.map((p)=>DropdownMenuItem(value:p['id'].toString(),child:Text(p['name'].toString(),overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState(()=>selectedProductId=v)),
      if(selectedProductId!=null)Padding(padding:const EdgeInsets.only(top:4),child:Text('Disponible dans le dépôt source : '+money(available(selectedProductId!)),style:const TextStyle(fontSize:12))),
      TextField(controller:qtyController,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantité à transférer')),
      const SizedBox(height:8),
      OutlinedButton.icon(onPressed:addProduct,icon:const Icon(Icons.add),label:const Text('Ajouter au transfert')),
      ...cart.entries.map((e){final p=products.firstWhere((x)=>x['id']==e.key,orElse:()=>{});return ListTile(dense:true,title:Text(p['name']?.toString()??'Produit'),subtitle:Text('Quantité : '+money(e.value)),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>setState(()=>cart.remove(e.key))));}),
      TextField(controller:noteController,decoration:const InputDecoration(labelText:'Note (facultatif)')),
      const SizedBox(height:10),
      SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:saving?null:submit,icon:const Icon(Icons.swap_horiz),label:Text(saving?'Transfert…':'Valider le transfert'))),
    ]))),
    const SizedBox(height:8),const Text('Historique des transferts',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16)),
    if(history.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(12),child:Text('Aucun transfert enregistré.'))),
    ...history.map((h)=>Card(child:ExpansionTile(title:Text(h['transferNumber']?.toString()??h['transfer_number']?.toString()??'Transfert',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(warehouseName(h['fromWarehouseId']?.toString()??h['from_warehouse_id']?.toString())+' → '+warehouseName(h['toWarehouseId']?.toString()??h['to_warehouse_id']?.toString())),children:[...(h['items'] as List? ?? []).whereType<Map>().map((item)=>ListTile(dense:true,title:Text(item['productNameSnapshot']?.toString()??item['product_name_snapshot']?.toString()??'Produit'),trailing:Text(money((item['quantity'] as num?)?.toDouble()??0))))]))),
  ]);}));
}
