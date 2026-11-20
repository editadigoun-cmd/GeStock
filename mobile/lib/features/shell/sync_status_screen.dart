import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class SyncStatusScreen extends ConsumerStatefulWidget {
  const SyncStatusScreen({super.key});
  @override
  ConsumerState<SyncStatusScreen> createState()=>_SyncStatusScreenState();
}
class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen>{
  bool _loading=true,_working=false;
  int _queued=0,_failed=0,_conflict=0,_total=0;
  List<Map<String,Object?>> _rows=[];
  String? _error;
  Future<void> _load()async{
    setState(()=>_loading=true);
    try{
      final db=await ref.read(databaseProvider).database;
      final counts=await db.rawQuery("SELECT status,COUNT(*) AS count FROM outbox GROUP BY status");
      int q=0,f=0,c=0,t=0;
      for(final r in counts){final n=(r['count'] as num?)?.toInt()??0;t+=n;switch(r['status']){case 'queued':q=n;break;case 'failed':f=n;break;case 'conflict':c=n;break;}}
      final rows=await db.rawQuery("SELECT id,entity_type,operation,entity_id,created_at,attempts,status,last_error FROM outbox ORDER BY created_at DESC LIMIT 50");
      if(!mounted)return;setState((){_queued=q;_failed=f;_conflict=c;_total=t;_rows=rows;_error=null;});
    }catch(e){if(mounted)setState(()=>_error=e.toString());}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  Future<void> _sync({bool retry=false})async{
    setState(()=>_working=true);
    try{
      final ok=retry?await ref.read(syncServiceProvider).retryFailed():await ref.read(syncServiceProvider).syncPending();
      await _load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?'Synchronisation terminée.':'Synchronisation partielle. Vérifiez votre connexion et les opérations ci-dessous.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Synchronisation impossible: '+e.toString())));}
    finally{if(mounted)setState(()=>_working=false);}
  }
  @override void initState(){super.initState();_load();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Synchronisation')),
    body:_loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
      if(_error!=null)Card(child:Padding(padding:const EdgeInsets.all(14),child:Text('Erreur locale: '+_error!))),
      Row(children:[Expanded(child:_stat('En attente',_queued,Colors.orange)),const SizedBox(width:8),Expanded(child:_stat('Échecs',_failed,Colors.red)),const SizedBox(width:8),Expanded(child:_stat('Conflits',_conflict,Colors.deepPurple))]),
      const SizedBox(height:10),Card(child:ListTile(title:Text('Total opérations locales: '+_total.toString()),subtitle:const Text('Les opérations restent enregistrées sur l’appareil tant qu’elles ne sont pas confirmées par le serveur.'))),
      const SizedBox(height:10),SizedBox(height:48,child:FilledButton.icon(onPressed:_working?null:()=>_sync(),icon:_working?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.sync),label:Text(_working?'Synchronisation…':'Synchroniser maintenant'))),
      if(_failed>0||_conflict>0)Padding(padding:const EdgeInsets.only(top:8),child:OutlinedButton.icon(onPressed:_working?null:()=>_sync(retry:true),icon:const Icon(Icons.replay),label:const Text('Réessayer les opérations en échec / conflit'))),
      const SizedBox(height:18),const Text('Journal local',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:8),
      if(_rows.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(14),child:Text('Aucune opération locale.'))),
      ..._rows.map((r)=>Card(child:ListTile(leading:Icon(_icon(r['status']?.toString()),color:_color(r['status']?.toString())),title:Text(r['entity_type'].toString()+' · '+r['operation'].toString(),style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('ID '+r['entity_id'].toString()+'\n'+r['created_at'].toString()+' · Tentatives '+r['attempts'].toString()+(r['last_error']==null?'':'\nErreur: '+r['last_error'].toString())),trailing:Text(r['status']?.toString()??'—')))),
    ])),
  );
  Widget _stat(String label,int value,Color color)=>Card(child:Padding(padding:const EdgeInsets.symmetric(vertical:14,horizontal:8),child:Column(children:[Text(label,style:const TextStyle(fontSize:11)),const SizedBox(height:5),Text(value.toString(),style:TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:color))])));
  IconData _icon(String? s)=>s=='failed'?Icons.error_outline:s=='conflict'?Icons.warning_amber_rounded:s=='queued'?Icons.schedule:Icons.check_circle_outline;
  Color _color(String? s)=>s=='failed'?Colors.red:s=='conflict'?Colors.deepPurple:s=='queued'?Colors.orange:Colors.green;
}
