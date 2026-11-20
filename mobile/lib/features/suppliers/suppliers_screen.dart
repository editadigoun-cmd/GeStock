import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});
  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String query = '';
  bool busy = false;
  final Set<String> pulled = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fournisseurs')),
      body: FutureBuilder<Map<String, Object?>?>(
        future: ref.read(businessRepositoryProvider).active(),
        builder: (context, businessSnapshot) {
          if (businessSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final business = businessSnapshot.data;
          if (business == null) return const Center(child: Text('Créez d’abord une entreprise.'));
          final businessId = business['id'].toString();
          if (pulled.add(businessId)) {
            ref.read(supplierRepositoryProvider).pullCloud(businessId).then((_) {
              if (mounted) setState(() {});
            }).catchError((_) {});
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher un fournisseur'),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: ref.read(supplierRepositoryProvider).list(businessId, query: query),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) return Center(child: Text(query.isEmpty ? 'Aucun fournisseur. Ajoutez votre premier fournisseur.' : 'Aucun résultat.'));
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final supplier = rows[index];
                      final details = [supplier['phone'], supplier['email'], supplier['address']]
                          .where((value) => value != null && value.toString().trim().isNotEmpty)
                          .join(' · ');
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
                        title: Text(supplier['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: details.isEmpty ? null : Text(details),
                        trailing: Icon(supplier['sync_state'] == 'synced' ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined),
                        onTap: () => _form(supplier),
                      );
                    },
                  );
                },
              ),
            ),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => _form(null),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau fournisseur'),
      ),
    );
  }

  Future<void> _form(Map<String, Object?>? supplier) async {
    if (busy) return;
    final business = await ref.read(businessRepositoryProvider).active();
    if (!mounted) return;
    if (business == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Créez d’abord une entreprise.')));
      return;
    }
    final businessId = business['id'].toString();
    final name = TextEditingController(text: supplier?['name']?.toString() ?? '');
    final phone = TextEditingController(text: supplier?['phone']?.toString() ?? '');
    final email = TextEditingController(text: supplier?['email']?.toString() ?? '');
    final address = TextEditingController(text: supplier?['address']?.toString() ?? '');
    final notes = TextEditingController(text: supplier?['notes']?.toString() ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(supplier == null ? 'Nouveau fournisseur' : 'Modifier fournisseur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nom *')),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone')),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Adresse')),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheetContext, true), child: const Text('Enregistrer'))),
            ]),
          ),
        ),
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty && mounted) {
      setState(() => busy = true);
      try {
        final repository = ref.read(supplierRepositoryProvider);
        if (supplier == null) {
          await repository.create(businessId: businessId, name: name.text, phone: phone.text, email: email.text, address: address.text, notes: notes.text);
        } else {
          await repository.update(businessId: businessId, supplierId: supplier['id'].toString(), name: name.text, phone: phone.text, email: email.text, address: address.text, notes: notes.text);
        }
        try { await ref.read(syncServiceProvider).syncPending(); } catch (_) {}
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fournisseur enregistré.')));
        }
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
    for (final controller in [name, phone, email, address, notes]) {
      controller.dispose();
    }
  }
}
