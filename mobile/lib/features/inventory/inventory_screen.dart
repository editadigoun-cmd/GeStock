import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/gestock_theme.dart';
class InventoryScreen extends StatelessWidget {
 const InventoryScreen({super.key});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Gestion des stocks'),actions:[IconButton(onPressed:()=>context.go('/products'),icon:const Icon(Icons.search_rounded))]),body:ListView(padding:const EdgeInsets.all(20),children:[
  Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[GeStockColors.deepEmerald,Color(0xFF087B60)]),borderRadius:BorderRadius.circular(23)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('VOTRE INVENTAIRE',style:TextStyle(color:GeStockColors.mint,fontSize:9,letterSpacing:1.3,fontWeight:FontWeight.w900)),SizedBox(height:9),Text('Gardez le contrôle\nsur chaque article.',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900,height:1.15)),SizedBox(height:14),Text('Suivi des entrées, sorties, seuils et ajustements.',style:TextStyle(color:Color(0xFFD1EEE5),fontSize:11))])),
  const SizedBox(height:18),const Row(children:[Expanded(child:_Stat(label:'Articles suivis',value:'—',icon:Icons.inventory_2_outlined)),SizedBox(width:10),Expanded(child:_Stat(label:'Alertes de stock',value:'—',icon:Icons.warning_amber_rounded))]),const SizedBox(height:22),const Text('Opérations de stock',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(height:10),
  _Action(icon:Icons.add_box_outlined,title:'Entrée de stock',subtitle:'Réception fournisseur ou ajout initial',tap:()=>context.go('/products')),
  const _Action(icon:Icons.remove_circle_outline,title:'Sortie et ajustement',subtitle:'Correction avec traçabilité'),
  const _Action(icon:Icons.swap_horiz_rounded,title:'Transfert entre dépôts',subtitle:'Déplacer des articles entre emplacements'),
  const _Action(icon:Icons.fact_check_outlined,title:'Inventaire physique',subtitle:'Comparer réel et théorique'),
  const SizedBox(height:10),const Text('Les mouvements définitifs seront inscrits dans un journal non destructif et synchronisés avec le serveur.',style:TextStyle(color:GeStockColors.muted,fontSize:11,height:1.4)),
 ]));
}
class _Stat extends StatelessWidget{const _Stat({required this.label,required this.value,required this.icon});final String label,value;final IconData icon;@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:GeStockColors.deepEmerald),const SizedBox(height:12),Text(value,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(color:GeStockColors.muted,fontSize:10))])));}
class _Action extends StatelessWidget{const _Action({required this.icon,required this.title,required this.subtitle,this.tap});final IconData icon;final String title,subtitle;final VoidCallback? tap;@override Widget build(BuildContext c)=>Card(child:ListTile(onTap:tap,leading:Icon(icon,color:GeStockColors.deepEmerald),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13)),subtitle:Text(subtitle,style:const TextStyle(fontSize:10,color:GeStockColors.muted)),trailing:const Icon(Icons.chevron_right_rounded)));}
