import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';
import '../../data/repositories/sale_math.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});
  @override ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final Map<String, double> cart = {};
  String paymentMethod = 'cash';
  bool saving = false;
  Future<void> _refresh() async { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ventes & encaissements'), actions: [
      IconButton(tooltip: 'Synchroniser', onPressed: saving ? null : _sync, icon: const Icon(Icons.sync_rounded)),
    ]),
    body: FutureBuilder<Map<String, Object?>?>(
      future: ref.read(businessRepositoryProvider).active(),
      builder: (context, businessSnapshot) {
        if (businessSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final business = businessSnapshot.data;
        if (business == null) return _emptyBusiness();
        final businessId = business['id'] as String;
        return FutureBuilder<List<Map<String, Object?>>>(
          future: ref.read(productRepositoryProvider).list(businessId),
          builder: (context, productSnapshot) {
            final products = productSnapshot.data ?? [];
            final cartProducts = products.where((p) => cart.containsKey(p['id'])).toList();
            final totals = _totals(cartProducts);
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              _header(business['name'].toString(), business['currency_code'].toString()),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Text('Catalogue', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                Text('${products.length} produits', style: const TextStyle(color: GeStockColors.muted, fontSize: 11)),
              ]),
              const SizedBox(height: 8),
              if (productSnapshot.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
              if (products.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Ajoutez des produits avant d’effectuer une vente.'))),
              ...products.map((product) {
                final quantity = (product['quantity'] as num?)?.toDouble() ?? 0;
                final selected = cart[product['id']] ?? 0;
                return Card(child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined, color: GeStockColors.deepEmerald),
                  title: Text(product['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Stock : ${quantity.toStringAsFixed(0)} · ${product['sku'] ?? 'Sans référence'}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${_money((product['sale_price'] as num?)?.toDouble() ?? 0, currency)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (selected > 0) Text('Panier × ${selected.toStringAsFixed(0)}', style: const TextStyle(color: GeStockColors.deepEmerald, fontSize: 10)),
                  ]),
                  onTap: () => _add(product, quantity),
                ));
              }),
              const SizedBox(height: 18),
              _cart(cartProducts, totals, business['currency_code']?.toString() ?? 'XOF'),
              const SizedBox(height: 12),
              if (cart.isNotEmpty) SizedBox(height: 52, child: FilledButton.icon(
                onPressed: saving ? null : () => _checkout(business, totals),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(saving ? 'Enregistrement…' : 'Valider la vente · ${_money(totals.total, currency)}'),
              )),
              const SizedBox(height: 24),
              _history(businessId),
            ]);
          },
        );
      },
    ),
  );

  Widget _header(String business, String currency) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [GeStockColors.deepEmerald, Color(0xFF087B60)]), borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('POINT DE VENTE', style: TextStyle(color: GeStockColors.mint, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7), const Text('Encaisser simplement.', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5), Text(business, style: const TextStyle(color: Color(0xFFD1EEE5), fontSize: 11)),
      const SizedBox(height: 9), Text('Mode hors ligne · ${currency}', style: const TextStyle(color: GeStockColors.mint, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _cart(List<Map<String, Object?>> products, dynamic totals, String currency) {
    final selected = products.where((p) => (cart[p['id']] ?? 0) > 0).toList();
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Panier', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), Text('${selected.length} articles', style: const TextStyle(color: GeStockColors.muted, fontSize: 11))]),
      if (selected.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Touchez un produit pour l’ajouter.', style: TextStyle(color: GeStockColors.muted, fontSize: 12))),
      ...selected.map((product) => Row(children: [
        Expanded(child: Text(product['name'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        IconButton(onPressed: () => _change(product, -1), icon: const Icon(Icons.remove_circle_outline, size: 20)),
        Text('${cart[product['id']]!.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900)),
        IconButton(onPressed: () => _add(product, (product['quantity'] as num).toDouble()), icon: const Icon(Icons.add_circle_outline, size: 20)),
      ])),
      if (selected.isNotEmpty) const Divider(),
      Row(children: [const Expanded(child: Text('Total à payer', style: TextStyle(fontWeight: FontWeight.w800))), Text(_money(totals.total), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: GeStockColors.deepEmerald))]),
    ])));
  }

  Widget _history(String businessId) => FutureBuilder<List<Map<String, Object?>>>(
    future: ref.read(salesRepositoryProvider).list(businessId),
    builder: (context, snapshot) {
      final rows = snapshot.data ?? [];
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: Text('Historique local', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), Text('${rows.length} ventes', style: const TextStyle(color: GeStockColors.muted, fontSize: 11))]),
        const SizedBox(height: 8),
        if (rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Aucune vente enregistrée.', style: TextStyle(color: GeStockColors.muted)))),
        ...rows.take(20).map((sale) => Card(child: ListTile(
          leading: Icon(sale['sync_state'] == 'synced' ? Icons.cloud_done_rounded : Icons.cloud_upload_outlined, color: sale['sync_state'] == 'synced' ? GeStockColors.deepEmerald : GeStockColors.orange),
          title: Text(sale['sale_number'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          subtitle: Text('${DateTime.tryParse(sale['sold_at'].toString())?.toLocal().toString().substring(0,16) ?? ''} · ${sale['payment_method']} · ${sale['sync_state']}', style: const TextStyle(fontSize: 10)),
          trailing: Text(_money((sale['total'] as num).toDouble(), sale['currency_code']?.toString() ?? 'XOF'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
        ))),
      ]);
    },
  );

  Future<void> _checkout(Map<String, Object?> business, dynamic totals) async {
    final method = await showModalBottomSheet<String>(context: context, builder: (context) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mode de paiement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8), Text('Total : ${_money(totals.total)}', style: const TextStyle(color: GeStockColors.deepEmerald, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ListTile(leading: const Icon(Icons.payments_outlined), title: const Text('Espèces'), subtitle: const Text('Paiement enregistré'), onTap: () => Navigator.pop(context, 'cash')),
        ListTile(leading: const Icon(Icons.phone_android_rounded), title: const Text('Mobile Money'), subtitle: const Text('En attente de confirmation du prestataire'), onTap: () => Navigator.pop(context, 'mobile_money')),
        ListTile(leading: const Icon(Icons.credit_card_rounded), title: const Text('Carte'), subtitle: const Text('En attente de confirmation du prestataire'), onTap: () => Navigator.pop(context, 'card')),
      ]),
    )));
    if (method == null) return;
    setState(() => saving = true);
    try {
      await ref.read(salesRepositoryProvider).createSale(businessId: business['id'] as String, currencyCode: business['currency_code']?.toString() ?? 'XOF', quantities: Map.of(cart), paymentMethod: method);
      cart.clear();
      try { await ref.read(syncServiceProvider).syncPending(); } catch (_) {}
      if (mounted) {
        await _refresh();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(method == 'cash' ? 'Vente enregistrée.' : 'Vente enregistrée · paiement à confirmer.')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> _sync() async {
    setState(() => saving = true);
    try {
      final ok = await ref.read(syncServiceProvider).retryFailed();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Synchronisation terminée.' : 'Des opérations restent en attente ou en conflit.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Synchronisation : $error')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  void _add(Map<String, Object?> product, double available) {
    final id = product['id'].toString();
    final next = (cart[id] ?? 0) + 1;
    if (next > available) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock insuffisant.'))); return; }
    setState(() => cart[id] = next);
  }
  void _change(Map<String, Object?> product, int delta) {
    final id = product['id'].toString();
    final next = (cart[id] ?? 0) + delta;
    setState(() { if (next <= 0) cart.remove(id); else cart[id] = next; });
  }
  SaleTotals _totals(List<Map<String, Object?>> products) {
    final lines = products.where((p) => (cart[p['id']] ?? 0) > 0).map((p) {
      final quantity = cart[p['id']]!;
      final price = (p['sale_price'] as num?)?.toDouble() ?? 0;
      final taxRate = (p['tax_rate'] as num?)?.toDouble() ?? 0;
      return SaleLineDraft(quantity: quantity, unitPrice: price, taxAmount: roundMoney(quantity * price * taxRate / 100));
    }).toList();
    return calculateSaleTotals(lines);
  }
  String _money(double amount, [String currency = 'XOF']) => '${amount.toStringAsFixed(0)} $currency';
  Widget _emptyBusiness() => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.storefront_outlined, size: 48, color: GeStockColors.muted), const SizedBox(height: 12),
    const Text('Créez votre entreprise avant d’encaisser.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
    const SizedBox(height: 12), FilledButton(onPressed: () => context.go('/business/setup'), child: const Text('Créer une entreprise')),
  ])));
}
