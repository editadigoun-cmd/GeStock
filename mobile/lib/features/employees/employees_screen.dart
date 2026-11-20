import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});
  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  bool busy = false;
  final email = TextEditingController();
  String role = 'staff';

  @override
  void dispose() { email.dispose(); super.dispose(); }

  String roleLabel(String value) => switch (value) {
    'owner' => 'Propriétaire','manager' => 'Gestionnaire','cashier' => 'Caissier','staff' => 'Employé',_ => value,
  };
  IconData roleIcon(String value) => switch (value) {
    'owner' => Icons.verified_user,'manager' => Icons.manage_accounts,'cashier' => Icons.point_of_sale,'staff' => Icons.person,_ => Icons.person,
  };

  Future<void> sendInvite(String businessId) async {
    final emailValue=email.text.trim();
    if(emailValue.isEmpty||!emailValue.contains('@')){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Adresse e-mail invalide.')));return;}
    setState(()=>busy=true);
    try{
      await ref.read(employeeRepositoryProvider).invite(businessId,emailValue,role);
      email.clear();
      if(mounted){Navigator.pop(context);setState((){});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Invitation envoyée par e-mail.')));}
    }catch(error){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error.toString().replaceFirst('Exception: ',''))));}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> edit(String businessId,Map<String,Object?> employee,{String? newRole,String? newStatus})async{
    setState(()=>busy=true);
    try{await ref.read(employeeRepositoryProvider).update(businessId,employee['membershipId'].toString(),role:newRole,status:newStatus);if(mounted)setState((){});}
    catch(error){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error.toString())));}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> showInvite(String businessId)async{
    role='staff';email.clear();
    await showDialog<void>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
      title:const Text('Inviter un employé'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Adresse e-mail',prefixIcon:Icon(Icons.email_outlined))),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Rôle proposé'),items:const[
          DropdownMenuItem(value:'staff',child:Text('Employé')),
          DropdownMenuItem(value:'cashier',child:Text('Caissier')),
          DropdownMenuItem(value:'manager',child:Text('Gestionnaire')),
        ],onChanged:(v){if(v!=null){role=v;setDialogState((){});}}),
        const SizedBox(height:8),
        const Text('Un e-mail sera envoyé avec un lien sécurisé. L’invitation expire après 7 jours.',style:TextStyle(fontSize:12)),
      ]),
      actions:[
        TextButton(onPressed:busy?null:()=>Navigator.pop(dialogContext),child:const Text('Annuler')),
        FilledButton(onPressed:busy?null:()=>sendInvite(businessId),child:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Text('Envoyer l’invitation')),
      ],
    )));
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Employés')),
    floatingActionButton:FloatingActionButton.extended(onPressed:busy?null:()async{final business=await ref.read(businessRepositoryProvider).active();if(business!=null&&mounted)await showInvite(business['id'].toString());},icon:const Icon(Icons.person_add_alt_1),label:const Text('Inviter')),
    body:FutureBuilder<Map<String,Object?>?>(future:ref.read(businessRepositoryProvider).active(),builder:(context,businessSnap){
      if(businessSnap.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
      final business=businessSnap.data;if(business==null)return const Center(child:Text('Créez d’abord une entreprise.'));
      final businessId=business['id'].toString();
      return FutureBuilder<List<Map<String,Object?>>>(future:ref.read(employeeRepositoryProvider).list(businessId),builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
        if(snapshot.hasError)return Center(child:Padding(padding:const EdgeInsets.all(24),child:Text('Erreur de chargement : ${snapshot.error}')));
        final employees=snapshot.data??[];
        return FutureBuilder<List<Map<String,Object?>>>(future:ref.read(employeeRepositoryProvider).invitations(businessId),builder:(context,invSnap){
          final invites=invSnap.data??[];
          final pending=invites.where((i)=>i['accepted_at']==null&&i['revoked_at']==null&&DateTime.tryParse(i['expires_at']?.toString()??'')?.isAfter(DateTime.now())==true).toList();
          return RefreshIndicator(onRefresh:()async{setState((){});await ref.read(employeeRepositoryProvider).list(businessId);await ref.read(employeeRepositoryProvider).invitations(businessId);},child:ListView(padding:const EdgeInsets.all(16),children:[
            Text('${employees.length} membre(s)',style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:10),
            if(employees.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:16),child:Text('Aucun membre pour le moment.')),
            ...employees.map((employee){final active=employee['status']=='active';final currentRole=employee['role']?.toString()??'staff';return Card(child:ListTile(leading:CircleAvatar(child:Icon(roleIcon(currentRole))),title:Text((employee['name']??employee['email']??'Employé').toString()),subtitle:Text('${employee['email']??''}\n${roleLabel(currentRole)} · ${active?'Actif':'Désactivé'}'),isThreeLine:true,trailing:currentRole=='owner'?const Icon(Icons.lock):PopupMenuButton<String>(enabled:!busy,itemBuilder:(_)=>[const PopupMenuItem(value:'manager',child:Text('Promouvoir gestionnaire')),const PopupMenuItem(value:'cashier',child:Text('Rôle caissier')),const PopupMenuItem(value:'staff',child:Text('Rôle employé')),PopupMenuItem(value:active?'inactive':'active',child:Text(active?'Désactiver':'Réactiver'))],onSelected:(v){if(v=='active'||v=='inactive')edit(businessId,employee,newStatus:v);else edit(businessId,employee,newRole:v);},)));}),
            const SizedBox(height:20),const Text('Invitations en attente',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),
            if(invSnap.connectionState==ConnectionState.waiting)const LinearProgressIndicator(),
            if(invSnap.hasError)Text('Impossible de charger les invitations : ${invSnap.error}'),
            if(pending.isEmpty&&!invSnap.hasError)const Text('Aucune invitation en attente.'),
            ...pending.map((invite)=>Card(child:ListTile(leading:const Icon(Icons.mail_outline),title:Text(invite['email']?.toString()??''),subtitle:Text('${roleLabel(invite['role']?.toString()??'staff')} · Expire le ${(invite['expires_at']?.toString()??'').split('T').first}'),trailing:const Icon(Icons.hourglass_top)))),
          ]));
        });
      });
    }),
  );
}
