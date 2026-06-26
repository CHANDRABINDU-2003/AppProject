import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Incoming farmer orders for the seller.
class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> {
  final _api = ApiService.instance;
  List<dynamic> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _orders = await _api.get("/seller/orders");
    } catch (e) {
      if (mounted) showResultDialog(context, "Error", "$e");
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = "${o["status"]}";
    final color = switch (status) {
      "delivered" => AppTheme.accentGreen,
      "shipped" => AppTheme.primaryGreen,
      "confirmed" => AppTheme.lightGreen,
      "cancelled" => AppTheme.danger,
      _ => AppTheme.deepAmber, // pending
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppTheme.lightGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("${o["product_name"] ?? "Order #${o["id"]}"}",
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppTheme.darkGreen)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _meta(Icons.person_outline,
                    "Ordered by: ${o["farmer_name"] ?? "Unknown"}"),
                _meta(Icons.shopping_bag_outlined, "Qty: ${o["quantity"]}"),
                _meta(Icons.location_on_outlined,
                    "Region: ${o["region_name"] ?? "—"}"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.textFaint),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(color: AppTheme.textFaint, fontSize: 12.5)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          const PageBody(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: PageHeader("Incoming orders",
                subtitle: "Orders placed by farmers on your products."),
          ),
          if (_orders.isEmpty)
            const PageBody(
              child: Text("No orders yet.", style: TextStyle(color: AppTheme.textFaint)),
            )
          else
            for (final o in _orders)
              PageBody(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: _orderCard(o as Map<String, dynamic>),
              ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
