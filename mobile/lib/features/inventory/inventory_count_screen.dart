import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';

class InventoryCountScreen extends ConsumerStatefulWidget{
 const InventoryCountScreen({super.key});
 @override ConsumerState<InventoryCountScreen> createState()=>_InventoryCountScreenState();
}
class _InventoryCountScreenState extends ConsumerState<InventoryCountScreen>{
 Map<String,Object?>? _business;
 List<Map<String,Object?>> _products=[];
 final Map<String,TextEditingController> _controllers={};
 bool _loading=true,_saving=false;
 @override void initState(){super.initState();_load();}
 @override void dispose(){for(final c in _controllers.values){c.dispose();}super.dispose();}
 Future<void> _load()async{
  final business=await ref.read(businessRepositoryProvider).active();
  if(business==null){if(mounted)setState(()=>_loading=false);return;}
  final rows=await ref.read(productRepositoryProvider).list(business['id'] as String);
  for(final p in rows){if((p['track_stock'] as num?)?.toInt()!=0){_controllers[p['id'] as String]=TextEditingController(text:((p['quantity'] as num?)?.toDouble()??0).toString());}}
  if(mounted)setState(()=>{_business=business;_products=rows;_loading=false;});
 }
 Future<void> _save()async{
  final business=_business;if(business==null)return;
  final changes=<({Map<String,Object?> product,double counted,double current,double delta})>[];
  for(final p in _products){
   final id=p['id'] as String;final controller=_controllers[id];if(controller==null)continue;
   final counted=double.tryParse(controller.text.replaceAll(',','.'));
   final current=(p['quantity'] as num?)?.toDouble()??0;
   if(counted==null||!counted.isFinite||counted<0){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Quantité invalide pour '+p['name'].toString())));return;}
   final delta=counted-current;if(delta.abs()>0.000001)changes.add((product:p,counted:counted,current:current,delta:delta));
  }
  if(changes.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Aucun écart à corriger.')));return;}
  setState(()=>_saving=true);
  try{
   for(final c in changes){await ref.read(productRepositoryProvider).adjustStock(businessId:business['id'] as String,productId:c.product['id'] as String,delta:c.delta,note:'Inventaire physique · stock théorique '+c.current.toString()+' · compté '+c.counted.toString());}
   try{await ref.read(syncServiceProvider).syncPending();}catch(_){}
   if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(changes.length.toString()+' écart(s) enregistré(s) localement.')));context.pop();}
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Inventaire partiellement enregistré: '+e.toString())));}
  finally{if(mounted)setState(()=>_saving=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Inventaire physique')),
  body:_loading?const Center(child:CircularProgressIndicator()):_business==null?const Center(child:Text('Créez d’abord une entreprise.')):Column(children:[
   Padding(padding:const EdgeInsets.all(16),child:Card(child:ListTile(title:Text(_business!['name'].toString()),subtitle:Text(_products.length.toString()+' produit(s) · saisissez les quantités réellement comptées')))),
   Expanded(child:ListView.separated(padding:const EdgeInsets.symmetric(horizontal:16),itemCount:_products.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){final p=_products[i];final id=p['id'] as String;final current=(p['quantity'] as num?)?.toDouble()??0;final controller=_controllers[id];if(controller==null)return const SizedBox.shrink();return Card(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(p['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w800)),Text('Théorique: '+current.toString(),style:const TextStyle(fontSize:12,color:Colors.grey)),if(p['sku']!=null&&p['sku'].toString().isNotEmpty)Text('Réf. '+p['sku'].toString(),style:const TextStyle(fontSize:11))])),SizedBox(width:110,child:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),textAlign:TextAlign.center,decoration:const InputDecoration(labelText:'Compté',border:OutlineInputBorder())))])));})),
   SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:SizedBox(width:double.infinity,height:50,child:FilledButton.icon(onPressed:_saving?null:_save,icon:_saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.check),label:Text(_saving?'Enregistrement…':'Valider les écarts'))))),
  ]),
 );
}
