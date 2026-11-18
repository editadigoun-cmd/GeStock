import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';
class BusinessesScreen extends ConsumerStatefulWidget {
 const BusinessesScreen({super.key});
 @override ConsumerState<BusinessesScreen> createState()=>_BusinessesScreenState();
}
class _BusinessesScreenState extends ConsumerState<BusinessesScreen>{
 late Future<List<Map<String,Object?>>> future;
 @override void initState(){super.initState();future=ref.read(businessRepositoryProvider).list();}
 void _refresh()=>setState(()=>future=ref.read(businessRepositoryProvider).list());
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Mes entreprises')),body:FutureBuilder<List<Map<String,Object?>>>(future:future,builder:(context,snapshot){
  if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
  final businesses=snapshot.data??[];
  if(businesses.isEmpty)return Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.storefront_outlined,size:54,color:GeStockColors.muted),const SizedBox(height:14),const Text('Aucune entreprise pour le moment',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17)),const SizedBox(height:7),const Text('Créez votre premier espace. Vous pourrez ensuite en gérer plusieurs.',textAlign:TextAlign.center,style:TextStyle(color:GeStockColors.muted,fontSize:12)),const SizedBox(height:18),FilledButton.icon(onPressed:()=>context.push('/business/setup').then((_)=>_refresh()),icon:const Icon(Icons.add),label:const Text('Créer une entreprise'))])));
  return ListView(padding:const EdgeInsets.all(18),children:[
   Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:const LinearGradient(colors:[GeStockColors.deepEmerald,Color(0xFF087B60)]),borderRadius:BorderRadius.circular(22)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('VOS ESPACES DE TRAVAIL',style:TextStyle(color:GeStockColors.mint,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.2)),SizedBox(height:9),Text('Toutes vos activités,\nau même endroit.',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900,height:1.15)),SizedBox(height:7),Text('Les données de chaque entreprise restent séparées.',style:TextStyle(color:Color(0xFFD1EEE5),fontSize:11))]),
   const SizedBox(height:18),...businesses.map((b)=>FutureBuilder<Map<String,Object?>?>(future:ref.read(businessRepositoryProvider).active(),builder:(context,active){
    final isActive=active.data?['id']==b['id'];
    return Card(child:ListTile(leading:Container(width:44,height:44,decoration:BoxDecoration(color:GeStockColors.emerald.withValues(alpha:.1),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.storefront_rounded,color:GeStockColors.deepEmerald)),title:Text(b['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${b['business_type']} · ${b['country_code']} · ${b['currency_code']}',style:const TextStyle(fontSize:10,color:GeStockColors.muted)),trailing:isActive?const Chip(label:Text('Active'),avatar:Icon(Icons.check_circle,size:15),visualDensity:VisualDensity.compact):const Icon(Icons.chevron_right_rounded),onTap:()async{await ref.read(businessRepositoryProvider).setActive(b['id'] as String);if(context.mounted)context.go('/home');}));
   })),
   const SizedBox(height:12),OutlinedButton.icon(onPressed:()=>context.push('/business/setup').then((_)=>_refresh()),icon:const Icon(Icons.add_business_rounded),label:const Text('Ajouter une entreprise')),
  ]);
 }),);
}
