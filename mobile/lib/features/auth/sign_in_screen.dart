import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';

class SignInScreen extends ConsumerStatefulWidget {
 const SignInScreen({super.key});
 @override ConsumerState<SignInScreen> createState()=>_SignInScreenState();
}
class _SignInScreenState extends ConsumerState<SignInScreen>{
 final email=TextEditingController(),password=TextEditingController();bool obscure=true,busy=false;
 @override void dispose(){email.dispose();password.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(body:Stack(children:[
  Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF063C35),Color(0xFF071D1A),Color(0xFF101C1A)]))),
  Positioned(top:-80,right:-60,child:_orb(230,GeStockColors.emerald.withValues(alpha:.15))),
  SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Container(width:58,height:58,decoration:BoxDecoration(gradient:const LinearGradient(colors:[GeStockColors.emerald,GeStockColors.deepEmerald]),borderRadius:BorderRadius.circular(19)),child:const Icon(Icons.all_inbox_rounded,color:Colors.white,size:30)),
   const SizedBox(height:28),const Text('Votre activité,\nmaîtrisée.',style:TextStyle(color:Colors.white,fontSize:34,height:1.08,fontWeight:FontWeight.w900,letterSpacing:-1.2)),
   const SizedBox(height:10),const Text('Toute votre entreprise. Un seul espace.',style:TextStyle(color:Color(0xFFB6D1C9),fontSize:14)),
   const SizedBox(height:34),
   Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:const Color(0xFFF9FCFA),borderRadius:BorderRadius.circular(27)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Connexion',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:GeStockColors.ink)),const SizedBox(height:6),const Text('Retrouvez votre espace de travail.',style:TextStyle(color:GeStockColors.muted,fontSize:12)),const SizedBox(height:22),
    TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Adresse e-mail',prefixIcon:Icon(Icons.mail_outline_rounded))),
    const SizedBox(height:13),TextField(controller:password,obscureText:obscure,decoration:InputDecoration(labelText:'Mot de passe',prefixIcon:const Icon(Icons.lock_outline_rounded),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_outlined:Icons.visibility_off_outlined)))),
    const SizedBox(height:20),SizedBox(width:double.infinity,height:53,child:FilledButton(onPressed:busy?_noop:_signIn,child:busy?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Text('Se connecter'))),
    const SizedBox(height:8),Center(child:TextButton(onPressed:busy?null:_signUp,child:const Text('Créer un compte'))),
   ])),
   const SizedBox(height:20),const Center(child:Text('SÉCURISÉ · MULTI-ENTREPRISES · HORS LIGNE',style:TextStyle(color:Color(0xFF8EAAA1),fontSize:9,letterSpacing:1,fontWeight:FontWeight.w800))),
   Center(child:TextButton(onPressed:()=>context.go('/home'),child:const Text('Aperçu de démonstration',style:TextStyle(color:GeStockColors.mint)))),
  ]))))),
 ]));
 Widget _orb(double size,Color color)=>Container(width:size,height:size,decoration:BoxDecoration(shape:BoxShape.circle,boxShadow:[BoxShadow(color:color,blurRadius:90,spreadRadius:25)]));
 void _noop(){}
 Future<void> _signIn()async{
  if(email.text.trim().isEmpty||password.text.isEmpty){_feedback('Renseignez votre e-mail et votre mot de passe.');return;}
  setState(()=>busy=true);
  try{await ref.read(authRepositoryProvider).signIn(email.text,password.text);if(mounted)context.go('/business/setup');}
  catch(e){_feedback(e.toString().replaceFirst('Exception: ','').replaceFirst('DioException [bad response]: ',''));}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _signUp()async{
  final name=TextEditingController();final pass=TextEditingController();
  final values=await showDialog<List<String>>(context:context,builder:(c)=>AlertDialog(title:const Text('Créer votre compte'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Nom complet')),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Adresse e-mail')),TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Mot de passe (8 caractères minimum)'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(c,[name.text,email.text,pass.text]),child:const Text('Créer'))]));
  if(values!=null){if(values[2].length<8){_feedback('Le mot de passe doit contenir au moins 8 caractères.');}else{setState(()=>busy=true);try{await ref.read(authRepositoryProvider).signUp(values[0],values[1],values[2]);if(mounted)context.go('/business/setup');}catch(e){_feedback(e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>busy=false);}}}
  name.dispose();pass.dispose();
 }
 void _feedback(String message){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}
}
