import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Gestion des stocks'), actions: [
      IconButton(onPressed: () => context.go('/products'), icon: const Icon(Icons.edit_note_rounded), tooltip: 'Catalogue et ajustements'),
    ]),
    body: FutureBuilder<Map<String, Object?>?>(
      future: ref.read(businessRepositoryProvider).active(),
      builder: (context, businessSnapshot) {
        if (businessSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final business = businessSnapshot.data;
        if (business == null) return const Center(child: Text('Créez d’abord une entreprise.'));
        final businessId = business['id'] as String;
        return FutureBuilder<Map<String, Object?>>(
          future: ref.read(productRepositoryProvider).stockSummary(businessId),
          builder: (context, summarySnapshot) {
            final summary = summarySnapshot.data ?? {};
            return ListView(padding: const EdgeInsets.all(18), children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [GeStockColors.deepEmerald, Color(0xFF087B60)]), borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('INVENTAIRE LOCAL', style: TextStyle(color: GeStockColors.mint, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8), Text(business['name'].toString(), style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8), const Text('Les quantités et mouvements sont conservés sur cet appareil et synchronisés dès que possible.', style: TextStyle(color: Color(0xFFD1EEE5), fontSize: 11, height: 1.4)),
              ])),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Stat(label: 'Produits', value: summary['products']?.toString() ?? '—', icon: Icons.inventory_2_outlined)),
                const SizedBox(width: 10), Expanded(child: _Stat(label: 'Unités en stock', value: (summary['units'] as num?)?.toStringAsFixed(0) ?? '—', icon: Icons.layers_outlined)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _Stat(label: 'Stock bas', value: summary['low_stock']?.toString() ?? '—', icon: Icons.warning_amber_rounded)),
                const SizedBox(width: 10), Expanded(child: _Stat(label: 'Mouvements', value: summary['movements']?.toString() ?? '—', icon: Icons.swap_vert_rounded)),
              ]),
              const SizedBox(height: 22),
              Row(children: [const Expanded(child: Text('Journal des mouvements', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), TextButton(onPressed: () => context.go('/products'), child: const Text('Ajuster'))]),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, Object?>>>(
                future: ref.read(productRepositoryProvider).movementHistory(businessId),
                builder: (context, historySnapshot) {
                  final rows = historySnapshot.data ?? [];
                  if (historySnapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                  if (rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Aucun mouvement enregistré.', style: TextStyle(color: GeStockColors.muted))));
                  return Column(children: rows.map((movement) {
                    final delta = (movement['quantity_delta'] as num?)?.toDouble() ?? 0;
                    final synced = movement['sync_state'] == 'synced';
                    return Card(child: ListTile(
                      leading: Icon(delta >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline, color: delta >= 0 ? GeStockColors.deepEmerald : GeStockColors.amber),
                      title: Text(movement['product_name']?.toString() ?? 'Produit', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      subtitle: Text('${movement['movement_type']} · ${movement['note'] ?? ''} · ${synced ? 'Synchronisé' : 'Local / en attente'}', style: const TextStyle(fontSize: 10)),
                      trailing: Text('${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ));
                  }).toList());
                },
              ),
              const SizedBox(height: 12),
              SizedBox(height: 50, child: OutlinedButton.icon(onPressed: () => context.go('/products'), icon: const Icon(Icons.inventory_2_outlined), label: const Text('Ouvrir le catalogue et ajuster le stock'))),
            ]);
          },
        );
      },
    ),
  );
  }

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
  final String label, value; final IconData icon;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: GeStockColors.deepEmerald), const SizedBox(height: 10), Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: GeStockColors.muted, fontSize: 10)),
  ])));
}
