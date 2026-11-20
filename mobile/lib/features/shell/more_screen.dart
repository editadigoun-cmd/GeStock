import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MoreScreen extends StatelessWidget {
 const MoreScreen({super.key});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Plus de fonctionnalités')),body:ListView(padding:const EdgeInsets.all(16),children:[
  _item(context,Icons.storefront_outlined,'Entreprise et magasins','Gestion des entreprises','/businesses'),
  _item(context,Icons.people_alt_outlined,'Employés','Ajouter, gérer les rôles et accès','/employees'),
  _item(context,Icons.local_shipping_outlined,'Fournisseurs','Contacts et fournisseurs','/suppliers'),
  _item(context,Icons.shopping_bag_outlined,'Achats & réceptions','Entrées de stock via achats','/purchases'),
  _item(context,Icons.receipt_long_outlined,'Dépenses','Enregistrer et suivre les dépenses','/expenses'),
  _item(context,Icons.point_of_sale_outlined,'Gestion de caisse','Ouverture, clôture et écarts','/cash'),
  _item(context,Icons.bar_chart_rounded,'Rapports & statistiques','Ventes, dépenses, marge et stock','/reports'),
  _item(context,Icons.sync_rounded,'Synchronisation','État des données, erreurs et relance','/sync'),
 ]),
 );
 Widget _item(BuildContext context,IconData icon,String title,String subtitle,String path)=>Card(child:ListTile(leading:CircleAvatar(child:Icon(icon)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_right),onTap:()=>context.go(path)));
}
