import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  @override
  void initState() {
    super.initState();
    _syncQuietly();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) _syncQuietly();
    });
  }
  Future<void> _syncQuietly() async { try { await ref.read(syncServiceProvider).syncPending(); } catch (_) {} }
  Future<void> _syncAndRefresh() async { await _syncQuietly(); if (mounted) setState(() {}); }
  @override
  void dispose() { _connectivitySubscription?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => SafeArea(bottom: false, child: _DashboardHome(
    onNavigate: (path) => context.go(path),
    onSync: _syncAndRefresh,
  ));
}

class _DashboardHome extends ConsumerWidget {
  const _DashboardHome({required this.onNavigate, required this.onSync});
  final ValueChanged<String> onNavigate;
  final VoidCallback onSync;
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<Map<String,Object?>?>(
    future: ref.read(businessRepositoryProvider).active(),
    builder: (context, businessSnapshot) {
      final business = businessSnapshot.data;
      if (businessSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (business == null) return _noBusiness(context);
      final businessId = business['id'] as String;
      return FutureBuilder<_DashboardData>(
        future: _loadData(ref, businessId),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final currency = business['currency_code']?.toString() ?? 'XOF';
          return ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 24), children: [
            Row(children: [
              Container(width: 42,height: 42,decoration:BoxDecoration(color:GeStockColors.deepEmerald,borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.storefront_rounded,color:Colors.white)),
              const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('GeStock',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text(business['name'].toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:GeStockColors.muted,fontSize:11))])),
              IconButton(onPressed:()=>onNavigate('/products'),icon:const Icon(Icons.search_rounded)),
              IconButton(onPressed:onSync,icon:const Icon(Icons.sync_rounded)),
            ]),
            const SizedBox(height:18),
            Container(padding:const EdgeInsets.all(19),decoration:BoxDecoration(gradient:const LinearGradient(colors:[GeStockColors.deepEmerald,Color(0xFF087B60)]),borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('ESPACE ACTIF',style:TextStyle(color:GeStockColors.mint,fontSize:9,letterSpacing:1.2,fontWeight:FontWeight.w900)),
              const SizedBox(height:9),const Text('Votre activité, en temps réel local.',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
              const SizedBox(height:8),Text('Les indicateurs ci-dessous proviennent des données enregistrées sur cet appareil.',style:TextStyle(color:Colors.white.withValues(alpha:.82),fontSize:11,height:1.4)),
              const SizedBox(height:10),InkWell(onTap:()=>onNavigate('/businesses'),child:Row(children:[const Icon(Icons.swap_horiz_rounded,color:GeStockColors.mint,size:16),const SizedBox(width:6),Text('Changer d’entreprise',style:TextStyle(color:GeStockColors.mint,fontWeight:FontWeight.w800,fontSize:11))])),
            ])),
            const SizedBox(height:20),const Text('Vue d’ensemble',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:10),
            GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.48,children:[
              _Metric(label:'Produits',value:data==null?'—':data.products.toString(),detail:'Catalogue local',icon:Icons.inventory_2_outlined),
              _Metric(label:'Unités en stock',value:data==null?'—':data.units.toStringAsFixed(0),detail:'Quantités disponibles',icon:Icons.layers_outlined),
              _Metric(label:'Stock bas',value:data==null?'—':data.lowStock.toString(),detail:'Sous seuil de réapprovisionnement',icon:Icons.warning_amber_rounded),
              _Metric(label:'Ventes aujourd’hui',value:data==null?'—':data.salesToday.toString(),detail:'Transactions locales',icon:Icons.point_of_sale_rounded),
            ]),
            const SizedBox(height:20),_Revenue(data:data,currency:currency),
            const SizedBox(height:20),const Text('Accès rapide',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:10),
            GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:4,crossAxisSpacing:8,childAspectRatio:.82,children:[
              _Action(icon:Icons.add_shopping_cart_rounded,label:'Nouvelle vente',color:const Color(0xFF00A982),onTap:()=>onNavigate('/sales')),
              _Action(icon:Icons.add_box_outlined,label:'Ajouter produit',color:const Color(0xFF4C8EDB),onTap:()=>onNavigate('/products')),
              _Action(icon:Icons.inventory_2_outlined,label:'Inventaire',color:const Color(0xFF8C75D9),onTap:()=>onNavigate('/inventory')),
              _Action(icon:Icons.storefront_outlined,label:'Entreprises',color:const Color(0xFFE39B43),onTap:()=>onNavigate('/businesses')),
            ]),
            const SizedBox(height:20),const Text('Activité récente',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:10),
            _Recent(data:data,currency:currency),
            const SizedBox(height:12),_SyncStatus(data:data,onSync:onSync),
          ]);
        },
      );
    },
  );

  static Future<_DashboardData> _loadData(WidgetRef ref,String businessId) async {
    final db=await ref.read(databaseProvider).database;
    final products=await db.query('products',where:'business_id = ?',whereArgs:[businessId]);
    var units=0.0,low=0;
    for(final product in products){final q=(product['quantity'] as num?)?.toDouble()??0;final min=(product['min_quantity'] as num?)?.toDouble()??0;units+=q;if(q<=min)low++;}
    final sales=await db.rawQuery("SELECT COUNT(*) count,COALESCE(SUM(total),0) total FROM sales WHERE business_id=? AND date(sold_at)=date('now')",[businessId]);
    final pending=await db.rawQuery("SELECT COUNT(*) count FROM outbox WHERE business_id=? AND status='queued'",[businessId]);
    final conflicts=await db.rawQuery("SELECT COUNT(*) count FROM outbox WHERE business_id=? AND status IN ('conflict','failed')",[businessId]);
    final recentSales=await db.query('sales',where:'business_id = ?',whereArgs:[businessId],orderBy:'sold_at DESC',limit:4);
    final recentMovements=await db.rawQuery("SELECT m.*,p.name product_name FROM stock_movements m LEFT JOIN products p ON p.id=m.product_id WHERE m.business_id=? ORDER BY m.occurred_at DESC LIMIT 4",[businessId]);
    return _DashboardData(products:products.length,units:units,lowStock:low,salesToday:(sales.first['count'] as int?)??0,revenueToday:(sales.first['total'] as num?)?.toDouble()??0,pending:(pending.first['count'] as int?)??0,conflicts:(conflicts.first['count'] as int?)??0,recentSales:recentSales,recentMovements:recentMovements);
  }

  Widget _noBusiness(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(26),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.storefront_outlined,size:52,color:GeStockColors.muted),const SizedBox(height:12),const Text('Votre espace GeStock',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:7),const Text('Créez une entreprise pour commencer à gérer le catalogue, les stocks et les ventes.',textAlign:TextAlign.center,style:TextStyle(color:GeStockColors.muted,fontSize:12)),const SizedBox(height:16),FilledButton(onPressed:()=>context.go('/business/setup'),child:const Text('Créer une entreprise')),
  ])));
}

class _DashboardData {
  const _DashboardData({required this.products,required this.units,required this.lowStock,required this.salesToday,required this.revenueToday,required this.pending,required this.conflicts,required this.recentSales,required this.recentMovements});
  final int products,lowStock,salesToday,pending,conflicts;
  final double units,revenueToday;
  final List<Map<String,Object?>> recentSales,recentMovements;
}
class _Metric extends StatelessWidget {
  const _Metric({required this.label,required this.value,required this.detail,required this.icon});
  final String label,value,detail;final IconData icon;
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:GeStockColors.deepEmerald,size:18),const Spacer(),Text(value,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800)),Text(detail,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:8,color:GeStockColors.muted))])));
}
class _Revenue extends StatelessWidget {
  const _Revenue({required this.data,required this.currency});final _DashboardData? data;final String currency;
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Ventes du jour',style:TextStyle(fontSize:12,fontWeight:FontWeight.w800)),const SizedBox(height:8),Text(data==null?'—':'${data!.revenueToday.toStringAsFixed(0)} $currency',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:GeStockColors.deepEmerald)),Text(data==null?'Calcul en cours':'${data!.salesToday} transaction(s) locale(s)',style:const TextStyle(color:GeStockColors.muted,fontSize:10))])));
}
class _Action extends StatelessWidget {
  const _Action({required this.icon,required this.label,required this.color,required this.onTap});final IconData icon;final String label;final Color color;final VoidCallback onTap;
  @override Widget build(BuildContext context)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(15),child:Column(children:[Container(width:52,height:52,decoration:BoxDecoration(color:color.withValues(alpha:.1),borderRadius:BorderRadius.circular(16)),child:Icon(icon,color:color)),const SizedBox(height:7),Text(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800,height:1.2))]));
}
class _Recent extends StatelessWidget {
  const _Recent({required this.data,required this.currency});final _DashboardData? data;final String currency;
  @override Widget build(BuildContext context){
    final sales=data?.recentSales??[];final movements=data?.recentMovements??[];
    return Card(child:Column(children:[
      if(sales.isEmpty&&movements.isEmpty)const Padding(padding:EdgeInsets.all(14),child:Text('Aucune activité enregistrée.',style:TextStyle(color:GeStockColors.muted,fontSize:11))),
      ...sales.map((s)=>ListTile(dense:true,leading:const Icon(Icons.receipt_long_rounded,color:GeStockColors.deepEmerald),title:Text(s['sale_number']?.toString()??'Vente',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:11)),subtitle:Text('${s['payment_method']} · ${s['sync_state']}',style:const TextStyle(fontSize:9)),trailing:Text('${(s['total'] as num).toStringAsFixed(0)} $currency',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:10)))),
      ...movements.map((m)=>ListTile(dense:true,leading:Icon((m['quantity_delta'] as num)<0?Icons.remove_circle_outline:Icons.add_circle_outline,color:GeStockColors.amber),title:Text(m['product_name']?.toString()??'Mouvement',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:11)),subtitle:Text('${m['movement_type']} · ${m['sync_state']}',style:const TextStyle(fontSize:9)),trailing:Text('${(m['quantity_delta'] as num).toStringAsFixed(0)}',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:10)))),
    ]));
  }
}
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.data,required this.onSync});final _DashboardData? data;final VoidCallback onSync;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),decoration:BoxDecoration(color:const Color(0xFFE8F7F1),borderRadius:BorderRadius.circular(14)),child:Row(children:[const Icon(Icons.cloud_sync_rounded,color:Color(0xFF008A68),size:17),const SizedBox(width:8),Expanded(child:Text('${data?.pending??0} en attente · ${data?.conflicts??0} conflit(s)',style:const TextStyle(color:Color(0xFF176B55),fontSize:10,fontWeight:FontWeight.w800))),TextButton(onPressed:onSync,child:const Text('Synchroniser'))]));
}
