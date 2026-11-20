import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../theme/gestock_theme.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String period = '30';

  String money(double value, String currency) => '${value.toStringAsFixed(0)} $currency';

  Future<Map<String, Object?>> load(String businessId) async {
    final db = await ref.read(databaseProvider).database;
    final days = int.tryParse(period) ?? 30;
    final start = days == 0
      ? DateTime.now().toIso8601String().substring(0, 10)
      : DateTime.now().subtract(Duration(days: days - 1)).toIso8601String().substring(0, 10);

    final sales = await db.rawQuery(
      "SELECT COUNT(*) AS count, COALESCE(SUM(total),0) AS revenue, COALESCE(SUM(amount_paid),0) AS collected FROM sales WHERE business_id=? AND status='completed' AND date(sold_at)>=date(?)",
      [businessId, start],
    );
    final expenses = await db.rawQuery(
      "SELECT COALESCE(SUM(amount),0) AS total, COUNT(*) AS count FROM expenses WHERE business_id=? AND date(paid_at)>=date(?)",
      [businessId, start],
    );
    final items = await db.rawQuery(
      "SELECT si.product_name_snapshot AS name, SUM(si.quantity) AS qty, SUM(si.line_total) AS revenue, COALESCE(SUM(si.quantity*COALESCE(p.purchase_price,0)),0) AS cost FROM sale_items si JOIN sales s ON s.id=si.sale_id LEFT JOIN products p ON p.id=si.product_id WHERE s.business_id=? AND s.status='completed' AND date(s.sold_at)>=date(?) GROUP BY si.product_name_snapshot ORDER BY revenue DESC LIMIT 5",
      [businessId, start],
    );
    final costRows = await db.rawQuery(
      "SELECT COALESCE(SUM(si.quantity*COALESCE(p.purchase_price,0)),0) AS cost FROM sale_items si JOIN sales s ON s.id=si.sale_id LEFT JOIN products p ON p.id=si.product_id WHERE s.business_id=? AND s.status='completed' AND date(s.sold_at)>=date(?)",
      [businessId, start],
    );
    final stock = await db.rawQuery(
      "SELECT COUNT(*) AS products, COALESCE(SUM(quantity),0) AS units, COALESCE(SUM(quantity*purchase_price),0) AS value FROM products WHERE business_id=?",
      [businessId],
    );
    final low = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM products WHERE business_id=? AND quantity<=min_quantity",
      [businessId],
    );

    final revenue = (sales.first['revenue'] as num).toDouble();
    final expense = (expenses.first['total'] as num).toDouble();
    final estimatedCost = (costRows.first['cost'] as num).toDouble();
    return {
      'start': start,
      'salesCount': (sales.first['count'] as num).toInt(),
      'revenue': revenue,
      'collected': (sales.first['collected'] as num).toDouble(),
      'expenses': expense,
      'expenseCount': (expenses.first['count'] as num).toInt(),
      'estimatedCost': estimatedCost,
      'estimatedGross': revenue - estimatedCost,
      'netAfterExpenses': revenue - estimatedCost - expense,
      'top': items,
      'stockProducts': (stock.first['products'] as num).toInt(),
      'stockUnits': (stock.first['units'] as num).toDouble(),
      'stockValue': (stock.first['value'] as num).toDouble(),
      'lowStock': (low.first['count'] as num).toInt(),
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rapports & statistiques')),
    body: FutureBuilder<Map<String, Object?>?>(
      future: ref.read(businessRepositoryProvider).active(),
      builder: (context, businessSnapshot) {
        if (businessSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final business = businessSnapshot.data;
        if (business == null) return const Center(child: Text('Créez d’abord une entreprise.'));
        final businessId = business['id'].toString();
        final currency = business['currency_code']?.toString() ?? 'XOF';
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '0', label: Text('Aujourd’hui')),
                  ButtonSegment(value: '7', label: Text('7 jours')),
                  ButtonSegment(value: '30', label: Text('30 jours')),
                ],
                selected: {period},
                onSelectionChanged: (values) => setState(() => period = values.first),
              ),
            ),
            Expanded(
              child: FutureBuilder<Map<String, Object?>>(
                future: load(businessId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text('Erreur : ${snapshot.error}'));
                  final data = snapshot.data!;
                  final top = data['top'] as List<Map<String, Object?>>;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    children: [
                      Text('Depuis le ${data['start']}', style: const TextStyle(color: GeStockColors.muted, fontSize: 12)),
                      const SizedBox(height: 12),
                      _metricCard('Chiffre d’affaires', money(data['revenue'] as double, currency), Icons.trending_up, GeStockColors.deepEmerald),
                      _metricCard('Encaissements enregistrés', money(data['collected'] as double, currency), Icons.payments_outlined, Colors.blue),
                      _metricCard('Dépenses', money(data['expenses'] as double, currency), Icons.receipt_long_outlined, Colors.orange),
                      _metricCard('Marge brute estimée', money(data['estimatedGross'] as double, currency), Icons.analytics_outlined, Colors.purple, caption: 'Basée sur le prix d’achat actuel des produits'),
                      _metricCard('Résultat estimé après dépenses', money(data['netAfterExpenses'] as double, currency), Icons.account_balance_wallet_outlined, Colors.teal),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Activité', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              _line('Transactions', data['salesCount'].toString()),
                              _line('Dépenses enregistrées', data['expenseCount'].toString()),
                              _line('Stock : produits', data['stockProducts'].toString()),
                              _line('Stock : unités', (data['stockUnits'] as double).toStringAsFixed(0)),
                              _line('Valeur du stock au coût', money(data['stockValue'] as double, currency)),
                              _line('Produits en stock bas', data['lowStock'].toString()),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Top produits vendus', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              if (top.isEmpty) const Text('Aucune vente sur cette période.')
                              else ...top.map((item) => ListTile(
                                dense: true,
                                title: Text(item['name']?.toString() ?? 'Produit'),
                                subtitle: Text('${(item['qty'] as num).toDouble().toStringAsFixed(0)} unité(s)'),
                                trailing: Text(money((item['revenue'] as num).toDouble(), currency), style: const TextStyle(fontWeight: FontWeight.bold)),
                              )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ces chiffres sont calculés à partir des données présentes localement sur l’appareil. Synchronisez pour conserver les données à jour.',
                        style: TextStyle(fontSize: 11, color: GeStockColors.muted),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _metricCard(String title, String value, IconData icon, Color color, {String? caption}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: .12), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                if (caption != null) Text(caption, style: const TextStyle(fontSize: 10, color: GeStockColors.muted)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _line(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [Expanded(child: Text(title)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );
}
