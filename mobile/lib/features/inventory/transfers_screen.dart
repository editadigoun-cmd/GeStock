import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:uuid/uuid.dart';
import '../../app/providers.dart';

class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});
  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  final Dio dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('GESTOCK_API_URL', defaultValue: 'https://gestock-api.ccds22431.workers.dev'),
    headers: {'Content-Type': 'application/json'},
  ));
  final quantityController = TextEditingController(text: '1');
  final noteController = TextEditingController();
  bool loading = false;
  bool saving = false;
  String? error;
  String? businessId;
  String? sourceId;
  String? destinationId;
  String? selectedProductId;\n  String? pendingTransferId;
  final Map<String, double> cart = {};
  List<Map<String, Object?>> warehouses = [];
  List<Map<String, Object?>> levels = [];
  List<Map<String, Object?>> products = [];
  List<Map<String, Object?>> history = [];
  late Future<Map<String, Object?>?> businessFuture;

  @override
  void initState() {
    super.initState();
    businessFuture = ref.read(businessRepositoryProvider).active();
  }

  @override
  void dispose() {
    quantityController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<String> _token() async => ref.read(authRepositoryProvider).getAccessToken();

  Future<void> _load(String id) async {
    setState(() { loading = true; error = null; businessId = id; });
    try {
      final token = await _token();
      final options = Options(headers: {'Authorization': 'Bearer ' + token});
      final warehouseResponse = await dio.get('/v1/stock/warehouses', queryParameters: {'business_id': id}, options: options);
      final levelsResponse = await dio.get('/v1/stock/levels', queryParameters: {'business_id': id}, options: options);
      final transfersResponse = await dio.get('/v1/stock/transfers', queryParameters: {'business_id': id}, options: options);
      final localProducts = await ref.read(productRepositoryProvider).list(id);
      warehouses = (warehouseResponse.data['data'] as List).whereType<Map>().map((e) => Map<String, Object?>.from(e)).toList();
      levels = (levelsResponse.data['data'] as List).whereType<Map>().map((e) => Map<String, Object?>.from(e)).toList();
      history = (transfersResponse.data['data'] as List).whereType<Map>().map((e) => Map<String, Object?>.from(e)).toList();
      products = localProducts;
      if (sourceId == null && warehouses.isNotEmpty) {
        final defaultWarehouse = warehouses.where((w) => (w['isDefault'] ?? w['is_default']) == 1).toList();
        sourceId = (defaultWarehouse.isNotEmpty ? defaultWarehouse.first : warehouses.first)['id']?.toString();
      }
      if (destinationId == null && warehouses.length > 1) {
        destinationId = warehouses.firstWhere((w) => w['id'].toString() != sourceId)['id'].toString();
      }
      if (sourceId == destinationId) destinationId = null;
      businessId = id;
    } catch (e) {
      error = _message(e);
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      return error.message ?? 'Erreur réseau';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  double _available(String productId) {
    return levels.where((row) =>
      (row['warehouse_id'] ?? row['warehouseId'])?.toString() == sourceId &&
      (row['product_id'] ?? row['productId'])?.toString() == productId
    ).fold<double>(0, (sum, row) => sum + ((row['quantity'] as num?)?.toDouble() ?? 0));
  }

  String _warehouseName(String? id) {
    final row = warehouses.where((w) => w['id']?.toString() == id).toList();
    return row.isEmpty ? 'Dépôt' : row.first['name']?.toString() ?? 'Dépôt';
  }

  String _qty(double value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 2);

  void _toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addProduct() async {
    final id = selectedProductId;
    final qty = double.tryParse(quantityController.text.replaceAll(',', '.'));
    if (id == null || qty == null || !qty.isFinite || qty <= 0) {
      _toast('Choisissez un produit et une quantité valide.');
      return;
    }
    final next = (cart[id] ?? 0) + qty;
    if (next > _available(id)) {
      _toast('Stock insuffisant. Disponible : ' + _qty(_available(id)));
      return;
    }
    setState(() { cart[id] = next; });
  }

  Future<void> _createWarehouse() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau dépôt'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Nom du dépôt')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Créer')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || businessId == null) return;
    try {
      final token = await _token();
      await dio.post('/v1/stock/warehouses', data: {'business_id': businessId, 'name': name}, options: Options(headers: {'Authorization': 'Bearer ' + token}));
      await _load(businessId!);
      _toast('Dépôt créé.');
    } catch (e) {
      _toast(_message(e));
    }
  }

  Future<void> _submit() async {
    if (sourceId == null || destinationId == null || sourceId == destinationId || cart.isEmpty || businessId == null) {
      _toast('Choisissez deux dépôts différents et ajoutez au moins un produit.');
      return;
    }
    setState(() { saving = true; });
    try {
      final token = await _token();
      final payload = {
        'business_id': businessId,
        'from_warehouse_id': sourceId,
        'to_warehouse_id': destinationId,
        'note': noteController.text.trim(),
        'items': cart.entries.map((entry) => {'product_id': entry.key, 'quantity': entry.value}).toList(),
      };
      final response = await dio.post('/v1/stock/transfers', data: payload, options: Options(headers: {'Authorization': 'Bearer ' + token}));
      final number = response.data['data']?['transferNumber']?.toString() ?? 'Transfert enregistré';
      cart.clear();
      noteController.clear();
      await _load(businessId!);
      try { await ref.read(syncServiceProvider).syncPending(); } catch (_) {}
      _toast(number + ' · Stocks actualisés');
    } catch (e) {
      _toast(_message(e));
    } finally {
      if (mounted) setState(() { saving = false; });
    }
  }

  Widget _warehouseDropdown({required String label, required String? value, required List<Map<String, Object?>> options, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: options.map((w) => DropdownMenuItem<String>(value: w['id'].toString(), child: Text(w['name'].toString(), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _transferHistory(Map<String, Object?> row) {
    final items = (row['items'] as List? ?? []).whereType<Map>().toList();
    final number = row['transferNumber']?.toString() ?? row['transfer_number']?.toString() ?? 'Transfert';
    final from = row['fromWarehouseId']?.toString() ?? row['from_warehouse_id']?.toString();
    final to = row['toWarehouseId']?.toString() ?? row['to_warehouse_id']?.toString();
    final date = row['transferredAt']?.toString() ?? row['transferred_at']?.toString() ?? '';
    return Card(
      child: ExpansionTile(
        title: Text(number, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_warehouseName(from) + ' → ' + _warehouseName(to) + (date.isEmpty ? '' : ' · ' + date.substring(0, 10))),
        children: items.map((item) => ListTile(
          dense: true,
          title: Text(item['productNameSnapshot']?.toString() ?? item['product_name_snapshot']?.toString() ?? 'Produit'),
          trailing: Text(_qty((item['quantity'] as num?)?.toDouble() ?? 0)),
        )).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferts de stock'),
        actions: [
          IconButton(tooltip: 'Créer un dépôt', onPressed: loading ? null : _createWarehouse, icon: const Icon(Icons.add_business_outlined)),
          IconButton(tooltip: 'Actualiser', onPressed: loading || businessId == null ? null : () => _load(businessId!), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<Map<String, Object?>?>(
        future: businessFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final business = snapshot.data;
          if (business == null) return const Center(child: Text('Créez une entreprise avant de gérer les transferts.'));
          final id = business['id'].toString();
          if (businessId != id && !loading) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _load(id));
          }
          if (loading && warehouses.isEmpty) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Transferts en ligne : le stock est retiré du dépôt source et ajouté au dépôt destination.'))),
              if (error != null) Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
              if (warehouses.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Aucun dépôt. Créez un dépôt pour commencer.'))),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Origine et destination', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      _warehouseDropdown(label: 'Dépôt source', value: sourceId, options: warehouses, onChanged: (v) {
                        setState(() {
                          sourceId = v;
                          if (destinationId == v) destinationId = null;
                        });
                      }),
                      const SizedBox(height: 8),
                      _warehouseDropdown(label: 'Dépôt destination', value: destinationId, options: warehouses.where((w) => w['id'].toString() != sourceId).toList(), onChanged: (v) => setState(() { destinationId = v; })),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ajouter des produits', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedProductId,
                        decoration: const InputDecoration(labelText: 'Produit'),
                        items: products.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text(p['name'].toString(), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() { selectedProductId = v; }),
                      ),
                      if (selectedProductId != null) Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Disponible dans le dépôt source : ' + _qty(_available(selectedProductId!)), style: const TextStyle(fontSize: 12)),
                      ),
                      TextField(controller: quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantité à transférer')),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Ajouter au transfert')),
                      ...cart.entries.map((entry) {
                        final product = products.where((p) => p['id'] == entry.key).toList();
                        final name = product.isEmpty ? 'Produit' : product.first['name'].toString();
                        return ListTile(
                          dense: true,
                          title: Text(name),
                          subtitle: Text('Quantité : ' + _qty(entry.value)),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() { cart.remove(entry.key); })),
                        );
                      }),
                      TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (facultatif)')),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: saving ? null : _submit,
                          icon: const Icon(Icons.swap_horiz),
                          label: Text(saving ? 'Transfert…' : 'Valider le transfert'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Historique des transferts', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              if (history.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Aucun transfert enregistré.'))),
              ...history.map(_transferHistory),
            ],
          );
        },
      ),
    );
  }
}
