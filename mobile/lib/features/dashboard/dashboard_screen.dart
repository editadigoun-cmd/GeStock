import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
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

  Future<void> _syncQuietly() async {
    try { await ref.read(syncServiceProvider).syncPending(); } catch (_) { /* Offline or API not configured: keep the local queue. */ }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: _DashboardHome(onNavigate: (index) {
      final routes = ['/home', '/products', '/sales', '/inventory'];
      context.go(routes[index.clamp(0, routes.length - 1).toInt()]);
    }),
  );
}

class _DashboardHome extends StatelessWidget {
  const _DashboardHome({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _TopBar(),
              const SizedBox(height: 25),
              _WelcomePanel().animate().fadeIn(duration: 450.ms).slideY(begin: .08, end: 0),
              const SizedBox(height: 22),
              _SectionHeading(title: 'Vue d’ensemble', trailing: 'Aujourd’hui'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: width > 520 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: width > 520 ? 1.45 : 1.32,
                children: const [
                  _MetricCard(label: 'Chiffre d’affaires', value: '248 500', unit: 'FCFA', icon: Icons.trending_up_rounded, tone: _MetricTone.green, change: '+12,8 %'),
                  _MetricCard(label: 'Ventes réalisées', value: '38', unit: 'transactions', icon: Icons.shopping_bag_outlined, tone: _MetricTone.blue, change: '+8 aujourd’hui'),
                  _MetricCard(label: 'Valeur du stock', value: '1,84 M', unit: 'FCFA', icon: Icons.inventory_2_outlined, tone: _MetricTone.purple, change: '126 produits'),
                  _MetricCard(label: 'À réapprovisionner', value: '07', unit: 'produits', icon: Icons.notifications_active_outlined, tone: _MetricTone.orange, change: 'À surveiller'),
                ],
              ),
              const SizedBox(height: 25),
              _SectionHeading(title: 'Activité commerciale', trailing: '7 derniers jours'),
              const SizedBox(height: 12),
              const _RevenueCard(),
              const SizedBox(height: 25),
              _SectionHeading(title: 'Accès rapide', trailing: 'Tout gérer'),
              const SizedBox(height: 12),
              _QuickActions(onNavigate: onNavigate),
              const SizedBox(height: 25),
              _SectionHeading(title: 'Activité récente', trailing: 'Voir tout'),
              const SizedBox(height: 12),
              const _RecentActivity(),
              const SizedBox(height: 18),
              const _SyncStatus(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [GeStockColors.deepEmerald, GeStockColors.emerald]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(padding: const EdgeInsets.all(5), child: SvgPicture.asset('assets/brand/gestock_mark.svg')),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GeStock', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.7)),
              Text('APERÇU · DONNÉES DE DÉMONSTRATION', style: TextStyle(fontSize: 9, letterSpacing: 1.1, color: GeStockColors.muted, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () {},
          style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: GeStockColors.ink),
          icon: const Icon(Icons.search_rounded),
        ),
        const SizedBox(width: 7),
        Stack(
          children: [
            IconButton.filledTonal(
              onPressed: () {},
              style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: GeStockColors.ink),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            Positioned(right: 10, top: 9, child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: GeStockColors.red, shape: BoxShape.circle))),
          ],
        ),
      ],
    );
  }
}

class _WelcomePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String,Object?>?>(
      future: ref.read(businessRepositoryProvider).active(),
      builder: (context,snapshot) {
        final business=snapshot.data;
        return Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient: const LinearGradient(begin: Alignment.topLeft,end: Alignment.bottomRight,colors: [Color(0xFF075446),Color(0xFF063C35),Color(0xFF092C29)]),
            boxShadow: [BoxShadow(color: GeStockColors.deepEmerald.withValues(alpha: .18),blurRadius: 25,offset: const Offset(0,12))],
          ),
          child: Stack(children: [
            Positioned(right: -18,top: -25,child: Icon(Icons.blur_on_rounded,size: 150,color: Colors.white.withValues(alpha: .055))),
            Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration: BoxDecoration(color:Colors.white.withValues(alpha:.12),borderRadius:BorderRadius.circular(30)),child:const Row(children:[Icon(Icons.circle,color:GeStockColors.mint,size:7),SizedBox(width:6),Text('ESPACE ACTIF',style:TextStyle(color:Colors.white,fontSize:9,letterSpacing:1,fontWeight:FontWeight.w800))])),
                const Spacer(),const Icon(Icons.more_horiz_rounded,color:Colors.white70),
              ]),
              const SizedBox(height:22),
              const Text('Bonjour 👋',style:TextStyle(color:Colors.white70,fontSize:14,fontWeight:FontWeight.w600)),
              const SizedBox(height:3),
              const Text('Votre activité,\nen pleine croissance.',style:TextStyle(color:Colors.white,fontSize:25,height:1.15,fontWeight:FontWeight.w900,letterSpacing:-.8)),
              const SizedBox(height:18),
              InkWell(
                onTap:()=>context.go('/businesses'),
                borderRadius:BorderRadius.circular(12),
                child:Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[
                  const Icon(Icons.storefront_rounded,color:GeStockColors.mint,size:16),
                  const SizedBox(width:7),
                  Expanded(child:Text(business?['name']?.toString()??'Aucune entreprise créée',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w700))),
                  Text('Changer',style:TextStyle(color:GeStockColors.mint.withValues(alpha:.95),fontSize:11,fontWeight:FontWeight.w800)),
                  const Icon(Icons.chevron_right_rounded,color:GeStockColors.mint,size:17),
                ])),
              ),
            ]),
          ]),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});
  final String title;
  final String trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -.4))),
    Text(trailing, style: const TextStyle(color: GeStockColors.deepEmerald, fontSize: 11, fontWeight: FontWeight.w800)),
    const Icon(Icons.chevron_right_rounded, size: 17, color: GeStockColors.deepEmerald),
  ]);
}

enum _MetricTone { green, blue, purple, orange }

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.unit, required this.icon, required this.tone, required this.change});
  final String label, value, unit, change;
  final IconData icon;
  final _MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _MetricTone.green => const Color(0xFF00A982),
      _MetricTone.blue => const Color(0xFF4C8EDB),
      _MetricTone.purple => const Color(0xFF8C75D9),
      _MetricTone.orange => const Color(0xFFE39B43),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 31, height: 31, decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 17)),
            const Spacer(),
            Icon(Icons.north_east_rounded, color: color.withValues(alpha: .8), size: 15),
          ]),
          const Spacer(),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.7)),
          Text(unit, style: const TextStyle(fontSize: 9, color: GeStockColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          Text(change, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w800)),
        ]),
      ),
    ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(.97, .97), end: const Offset(1, 1));
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard();
  @override
  Widget build(BuildContext context) {
    const values = [22.0, 36.0, 29.0, 58.0, 43.0, 74.0, 62.0];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('248 500 FCFA', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.8)),
              SizedBox(height: 3),
              Text('Revenus enregistrés cette semaine', style: TextStyle(fontSize: 10, color: GeStockColors.muted, fontWeight: FontWeight.w600)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFE7F8F2), borderRadius: BorderRadius.circular(9)), child: const Text('+12,8 %', style: TextStyle(color: Color(0xFF008A68), fontSize: 10, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 95,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (index) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 500 + index * 80),
                      curve: Curves.easeOutCubic,
                      height: values[index],
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: index == 5 ? [GeStockColors.mint, GeStockColors.emerald] : [const Color(0xFFB9EBDD), const Color(0xFFE1F4ED)]),
                      ),
                    ),
                  ]),
                ),
              )),
            ),
          ),
          const SizedBox(height: 9),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _ChartLabel('LUN'), _ChartLabel('MAR'), _ChartLabel('MER'), _ChartLabel('JEU'), _ChartLabel('VEN'), _ChartLabel('SAM'), _ChartLabel('DIM'),
          ]),
        ]),
      ),
    );
  }
}

class _ChartLabel extends StatelessWidget {
  const _ChartLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label, style: const TextStyle(color: GeStockColors.muted, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .5));
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.add_shopping_cart_rounded, 'Nouvelle vente', const Color(0xFF00A982), 2),
      (Icons.add_box_outlined, 'Ajouter produit', const Color(0xFF4C8EDB), 1),
      (Icons.local_shipping_outlined, 'Réception achat', const Color(0xFF8C75D9), 3),
      (Icons.bar_chart_rounded, 'Mes rapports', const Color(0xFFE39B43), 3),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 9, childAspectRatio: .83),
      itemBuilder: (context, index) {
        final item = actions[index];
        return InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => onNavigate(item.$4),
          child: Column(children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(color: item.$3.withValues(alpha: .1), borderRadius: BorderRadius.circular(18)), child: Icon(item.$1, color: item.$3, size: 23)),
            const SizedBox(height: 8),
            Text(item.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, height: 1.25, fontWeight: FontWeight.w800)),
          ]),
        );
      },
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Column(children: [
        _ActivityRow(icon: Icons.shopping_bag_rounded, color: Color(0xFF00A982), title: 'Vente #GS-00248', detail: 'Il y a 12 min · Paiement espèces', amount: '+ 18 500 F'),
        Divider(height: 1, indent: 58, endIndent: 16, color: GeStockColors.line),
        _ActivityRow(icon: Icons.inventory_2_rounded, color: Color(0xFF4C8EDB), title: 'Entrée de stock', detail: 'Il y a 48 min · 12 articles reçus', amount: '+ 12 articles'),
        Divider(height: 1, indent: 58, endIndent: 16, color: GeStockColors.line),
        _ActivityRow(icon: Icons.receipt_long_rounded, color: Color(0xFFE39B43), title: 'Dépense enregistrée', detail: 'Hier · Fournitures et emballages', amount: '− 7 500 F'),
      ]),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.icon, required this.color, required this.title, required this.detail, required this.amount});
  final IconData icon;
  final Color color;
  final String title, detail, amount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    child: Row(children: [
      Container(width: 35, height: 35, decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 17, color: color)),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(detail, style: const TextStyle(fontSize: 9, color: GeStockColors.muted, fontWeight: FontWeight.w600)),
      ])),
      Text(amount, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
    ]),
  );
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(color: const Color(0xFFE8F7F1), borderRadius: BorderRadius.circular(14)),
    child: const Row(children: [
      Icon(Icons.cloud_done_rounded, color: Color(0xFF008A68), size: 17),
      SizedBox(width: 8),
      Expanded(child: Text('Données enregistrées sur cet appareil', style: TextStyle(color: Color(0xFF176B55), fontSize: 10, fontWeight: FontWeight.w800))),
      Text('Synchronisation cloud en préparation', style: TextStyle(color: Color(0xFF176B55), fontSize: 9, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 76, height: 76, decoration: BoxDecoration(color: GeStockColors.emerald.withValues(alpha: .12), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.auto_awesome_rounded, color: GeStockColors.deepEmerald, size: 34)),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: GeStockColors.muted, fontSize: 13)),
        const SizedBox(height: 18),
        const Text('Module en cours de construction', style: TextStyle(color: GeStockColors.deepEmerald, fontWeight: FontWeight.w800, fontSize: 11)),
      ]),
    ),
  );
}
