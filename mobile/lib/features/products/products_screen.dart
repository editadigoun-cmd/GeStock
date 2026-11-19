import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  Future<void> _refresh() async {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue produits')),
      body: FutureBuilder<Map<String, Object?>?>(
        future: ref.read(businessRepositoryProvider).active(),
        builder: (context, businessSnapshot) {
          if (businessSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final business = businessSnapshot.data;
          if (business == null) return _emptyBusiness();
          final businessId = business['id'] as String;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined, color: GeStockColors.deepEmerald),
                      const SizedBox(width: 9),
                      Expanded(child: Text(business['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text(business['currency_code'].toString(), style: const TextStyle(color: GeStockColors.muted, fontSize: 10, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, Object?>>>(
                  future: ref.read(productRepositoryProvider).list(businessId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final rows = snapshot.data ?? [];
                    if (rows.isEmpty) return _empty();
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final product = rows[index];
                        final quantity = (product['quantity'] as num?)?.toDouble() ?? 0;
                        final minimum = (product['min_quantity'] as num?)?.toDouble() ?? 0;
                        return Card(
                          child: ListTile(
                            onTap: () => _adjustStock(business, product),
                            onLongPress: () => _add(context, product: product),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: GeStockColors.emerald.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)),
                              child: const Icon(Icons.inventory_2_outlined, color: GeStockColors.deepEmerald),
                            ),
                            title: Text(product['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(
                              'Réf. ${product['sku']?.toString() ?? '—'} · Stock ${quantity.toStringAsFixed(0)} · ${product['sale_price']} ${business['currency_code']} · Maintenir pour modifier',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${product['sale_price']} ${business['currency_code']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                Text(low ? 'Stock bas' : 'Disponible', style: TextStyle(fontSize: 9, color: low ? GeStockColors.red : GeStockColors.muted, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau produit'),
      ),
    );
  }

  Future<void> _adjustStock(Map<String, Object?> business, Map<String, Object?> product) async {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();
    var entry = true;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Wrap(
              runSpacing: 13,
              children: [
                Text('Mouvement · ${product['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Entrée'), icon: Icon(Icons.add_rounded)),
                    ButtonSegment(value: false, label: Text('Sortie'), icon: Icon(Icons.remove_rounded)),
                  ],
                  selected: {entry},
                  onSelectionChanged: (selection) => setSheetState(() => entry = selection.first),
                ),
                TextField(controller: quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantité')),
                TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Motif du mouvement')),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheetContext, true), child: const Text('Enregistrer le mouvement'))),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) {
      final amount = double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 0;
      try {
        await ref.read(productRepositoryProvider).adjustStock(
          businessId: business['id'] as String,
          productId: product['id'] as String,
          delta: entry ? amount : -amount,
          note: noteController.text.trim().isEmpty ? (entry ? 'Entrée de stock' : 'Sortie de stock') : noteController.text.trim(),
        );
        try { await ref.read(syncServiceProvider).syncPending(); } catch (_) {}
        if (mounted) {
          await _refresh();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mouvement enregistré sur cet appareil.')));
        }
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
    quantityController.dispose();
    noteController.dispose();
  }

  Widget _emptyBusiness() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 46, color: GeStockColors.muted),
          const SizedBox(height: 12),
          const Text('Créez d’abord votre entreprise', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.go('/business/setup'), child: const Text('Créer une entreprise')),
        ],
      ),
    ),
  );

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 48, color: GeStockColors.muted),
          const SizedBox(height: 12),
          const Text('Votre catalogue commence ici', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 6),
          const Text('Ajoutez vos premiers produits pour suivre quantités et prix.', textAlign: TextAlign.center, style: TextStyle(color: GeStockColors.muted, fontSize: 12)),
        ],
      ),
    ),
  );

  Future<void> _add(BuildContext context, {Map<String, Object?>? product}) async {
    final business = await ref.read(businessRepositoryProvider).active();
    if (business == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Créez d’abord une entreprise.')));
      return;
    }
    final name = TextEditingController(text: product?['name']?.toString() ?? '');
    final sku = TextEditingController(text: product?['sku']?.toString() ?? '');
    final barcode = TextEditingController(text: product?['barcode']?.toString() ?? '');
    final purchasePrice = TextEditingController(text: product?['purchase_price']?.toString() ?? '');
    final price = TextEditingController(text: product?['sale_price']?.toString() ?? '');
    final taxRate = TextEditingController(text: product?['tax_rate']?.toString() ?? '0');
    final quantity = TextEditingController(text: product?['quantity']?.toString() ?? '0');
    final minimum = TextEditingController(text: product?['min_quantity']?.toString() ?? '0');
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Wrap(
            runSpacing: 12,
            children: [
              Text(product == null ? 'Nouveau produit' : 'Modifier le produit', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nom du produit')),
              TextField(controller: sku, decoration: const InputDecoration(labelText: 'Référence / SKU')),
              TextField(controller: barcode, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Code-barres (facultatif)')),
              Row(children: [
                Expanded(child: TextField(controller: purchasePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prix d’achat'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prix de vente'))),
              ]),
              Row(children: [
                Expanded(child: TextField(controller: taxRate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Taxe (%)'))),
                if (product == null) const SizedBox(width: 10),
                if (product == null) Expanded(child: TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Stock initial'))),
              ]),
              TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Seuil d’alerte')),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheetContext, true), child: Text(product == null ? 'Créer localement' : 'Enregistrer les modifications'))),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && name.text.trim().isNotEmpty) {
      try {
        final repository = ref.read(productRepositoryProvider);
        if (product == null) {
          await repository.save(
            businessId: business['id'] as String, name: name.text, sku: sku.text, barcode: barcode.text,
            purchasePrice: double.tryParse(purchasePrice.text.replaceAll(',', '.')) ?? 0,
            salePrice: double.tryParse(price.text.replaceAll(',', '.')) ?? 0,
            taxRate: double.tryParse(taxRate.text.replaceAll(',', '.')) ?? 0,
            quantity: double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0,
            minQuantity: double.tryParse(minimum.text.replaceAll(',', '.')) ?? 0,
          );
        } else {
          await repository.update(
            businessId: business['id'] as String, productId: product['id'] as String,
            name: name.text, sku: sku.text, barcode: barcode.text,
            purchasePrice: double.tryParse(purchasePrice.text.replaceAll(',', '.')) ?? 0,
            salePrice: double.tryParse(price.text.replaceAll(',', '.')) ?? 0,
            taxRate: double.tryParse(taxRate.text.replaceAll(',', '.')) ?? 0,
            minQuantity: double.tryParse(minimum.text.replaceAll(',', '.')) ?? 0,
          );
        }
        try { await ref.read(syncServiceProvider).syncPending(); } catch (_) {}
        if (mounted) {
          await _refresh();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(product == null ? 'Produit enregistré localement.' : 'Modifications enregistrées localement.')));
        }
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    }
    name.dispose();
    sku.dispose();
    barcode.dispose();
    purchasePrice.dispose();
    price.dispose();
    taxRate.dispose();
    quantity.dispose();
    minimum.dispose();
  }

}
