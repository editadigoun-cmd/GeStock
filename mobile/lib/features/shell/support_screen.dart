import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class SupportScreen extends ConsumerStatefulWidget{
 const SupportScreen({super.key});
 @override ConsumerState<SupportScreen> createState()=>_SupportScreenState();
}
class _SupportScreenState extends ConsumerState<SupportScreen>{
 final _subject=TextEditingController(),_message=TextEditingController();
 bool _loading=true,_sending=false;
 List<Map<String,Object?>> _tickets=[];
 String? _businessId;
 @override void initState(){super.initState();_load();}
 @override void dispose(){_subject.dispose();_message.dispose();super.dispose();}
 Future<void> _load()async{
  try{final business=await ref.read(businessRepositoryProvider).active();final tickets=await ref.read(authRepositoryProvider).supportTickets();if(mounted)setState(()=>_tickets=tickets,_businessId=business?['id'] as String?,_loading=false);}
  catch(e){if(mounted)setState(()=>_loading=false);}
 }
 Future<void> _send()async{
  if(_subject.text.trim().length<3||_message.text.trim().length<10){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sujet et message requis (10 caractères minimum).')));return;}
  setState(()=>_sending=true);
  try{await ref.read(authRepositoryProvider).createSupportTicket(subject:_subject.text,message:_message.text,businessId:_businessId);_subject.clear();_message.clear();await _load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Votre demande a été envoyée.')));}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Envoi impossible: '+e.toString())));}
  finally{if(mounted)setState(()=>_sending=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Assistance GeStock')),body:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
  Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Text('Contacter le support',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17)),const SizedBox(height:12),TextField(controller:_subject,decoration:const InputDecoration(labelText:'Sujet')),const SizedBox(height:10),TextField(controller:_message,minLines:4,maxLines:7,decoration:const InputDecoration(labelText:'Décrivez votre problème ou votre question')),const SizedBox(height:12),FilledButton.icon(onPressed:_sending?null:_send,icon:_sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.send),label:Text(_sending?'Envoi…':'Envoyer la demande'))]))),
  const SizedBox(height:18),const Text('Mes demandes',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:8),
  if(_tickets.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(14),child:Text('Aucune demande enregistrée.'))),
  ..._tickets.map((t)=>Card(child:ListTile(title:Text(t['subject']?.toString()??'Demande',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text((t['message']?.toString()??'')+'\n'+(t['admin_reply']?.toString()??'Aucune réponse pour le moment'),isThreeLine:true),trailing:Text(t['status']?.toString()??'open')))),
 ]));
}
