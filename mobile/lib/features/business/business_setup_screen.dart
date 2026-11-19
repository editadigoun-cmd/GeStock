import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';
class BusinessSetupScreen extends ConsumerStatefulWidget {
 const BusinessSetupScreen({super.key});
 @override ConsumerState<BusinessSetupScreen> createState()=>_BusinessSetupScreenState();
}
class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen>{
 final name=TextEditingController(); String type='commerce',country='BJ',currency='XOF'; bool saving=false;
 final types=const {'commerce':'Commerce général','restaurant':'Restaurant / Café','pharmacie':'Pharmacie','grossiste':'Grossiste','services':'Prestations de services','mode':'Mode & accessoires','autre':'Autre activité'};
 @override void dispose(){name.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Nouvelle entreprise')),body:ListView(padding:const EdgeInsets.all(22),children:[
  Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[GeStockColors.deepEmerald,Color(0xFF087B60)]),borderRadius:BorderRadius.circular(24)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.storefront_rounded,color:GeStockColors.mint,size:30),SizedBox(height:16),Text('Un espace à votre image.',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),SizedBox(height:6),Text('Chaque entreprise possède ses propres stocks, ventes, équipes et paramètres.',style:TextStyle(color:Color(0xFFD1EEE5),height:1.4))])),
  const SizedBox(height:25),const Text('Nom de l’entreprise',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:9),TextField(controller:name,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(hintText:'Ex. Boutique Émeraude',prefixIcon:Icon(Icons.business_rounded))),
  const SizedBox(height:20),const Text('Secteur d’activité',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:9),DropdownButtonFormField<String>(value:type,items:types.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setState(()=>type=v??'commerce')),
  const SizedBox(height:20),const Text('Pays',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:9),DropdownButtonFormField<String>(value:country,items:const [DropdownMenuItem(value:'BJ',child:Text('Bénin')),DropdownMenuItem(value:'TG',child:Text('Togo')),DropdownMenuItem(value:'CI',child:Text('Côte d’Ivoire')),DropdownMenuItem(value:'CM',child:Text('Cameroun')),DropdownMenuItem(value:'SN',child:Text('Sénégal')),DropdownMenuItem(value:'FR',child:Text('France')),DropdownMenuItem(value:'US',child:Text('Autre pays'))],onChanged:(v){setState(() { country=v??'BJ'; currency=switch(country){'FR'=>'EUR','CM'=>'XAF','US'=>'USD',_=>'XOF'}; });}),
  const SizedBox(height:20),const Text('Devise principale',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:9),DropdownButtonFormField<String>(value:currency,items:const [DropdownMenuItem(value:'XOF',child:Text('Franc CFA BCEAO (XOF)')),DropdownMenuItem(value:'XAF',child:Text('Franc CFA BEAC (XAF)')),DropdownMenuItem(value:'EUR',child:Text('Euro (EUR)')),DropdownMenuItem(value:'USD',child:Text('Dollar US (USD)'))],onChanged:(v)=>setState(()=>currency=v??'XOF')),
  const SizedBox(height:28),SizedBox(height:54,child:FilledButton.icon(onPressed:saving?null:_save,icon:const Icon(Icons.arrow_forward_rounded),label:const Text('Créer mon espace'))),
  const SizedBox(height:10),const Text('Vous pourrez ajouter d’autres entreprises et modifier leurs paramètres plus tard.',textAlign:TextAlign.center,style:TextStyle(color:GeStockColors.muted,fontSize:11)),
 ]));
 Future<void> _save() async {if(name.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Saisissez le nom de votre entreprise.')));return;}setState(()=>saving=true);try{await ref.read(businessRepositoryProvider).create(name:name.text,type:type,country:country,currency:currency);if(mounted)context.go('/home');}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Erreur : $e')));}finally{if(mounted)setState(()=>saving=false);}}
}
