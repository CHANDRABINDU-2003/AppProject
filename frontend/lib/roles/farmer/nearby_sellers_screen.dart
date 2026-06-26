import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/services/auth_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Nearby sellers, matched by region — the farmer side of the Seller ↔ Farmer
/// mutual visibility. The farmer picks a region (defaults to their own), sees the
/// sellers registered there, expands a seller to browse their products, and
/// places an order right from the list. Orders are persisted on the backend
/// (`/marketplace/orders`) and shown in the "My orders" section below.
class NearbySellersScreen extends StatefulWidget {
  const NearbySellersScreen({super.key});

  @override
  State<NearbySellersScreen> createState() => _NearbySellersScreenState();
}

class _NearbySellersScreenState extends State<NearbySellersScreen> {
  final _api = ApiService.instance;
  List<dynamic> _regions = [];
  List<dynamic> _sellers = [];
  List<dynamic> _products = []; // products in the selected region (in stock)
  List<dynamic> _orders = []; // the farmer's own orders (all regions)
  int? _regionId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _regionId = AuthService.instance.currentUser?.regionId;
    _init();
  }

  Future<void> _init() async {
    try {
      _regions = await _api.get("/regions");
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final query = _regionId != null ? {"region_id": _regionId} : null;
      _sellers = await _api.get("/farmer/nearby-sellers", query);
      _products = await _api.get("/marketplace/products", query) as List;
      _orders = await _api.get("/marketplace/orders") as List;
    } catch (e) {
      if (mounted) showResultDialog(context, "Error", "$e");
    }
    if (mounted) setState(() => _loading = false);
  }

  /// In-stock products belonging to a given seller (by user id).
  List<dynamic> _productsOf(dynamic sellerId) =>
      _products.where((p) => p["seller_id"] == sellerId).toList();

  /// product_id → product name, for labelling the farmer's orders.
  String _productName(dynamic productId) {
    final match = _products.firstWhere(
      (p) => p["id"] == productId,
      orElse: () => null,
    );
    return match != null ? "${match["name"]}" : "Product #$productId";
  }

  Future<void> _order(Map product) async {
    final qty = await showDialog<int>(
      context: context,
      builder: (_) => _OrderDialog(product: product),
    );
    if (qty == null) return;
    try {
      await _api.post("/marketplace/orders", {
        "product_id": product["id"],
        "quantity": qty,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Order placed: $qty × ${product["name"]}")),
      );
      _load(); // refresh stock + my orders
    } catch (e) {
      if (mounted) showResultDialog(context, "Could not place order", "$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          PageBody(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader("Nearby sellers",
                    subtitle: "Browse sellers in your region and order supplies."),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _regionId,
                  decoration: const InputDecoration(labelText: "Region"),
                  items: _regions
                      .map((r) => DropdownMenuItem<int>(
                          value: r["id"], child: Text(r["region_name"])))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _regionId = v);
                    _load();
                  },
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _sellersSection(),
            _ordersSection(),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _sellersSection() {
    if (_sellers.isEmpty) {
      return const PageBody(
        child: Text("No sellers in this region yet.",
            style: TextStyle(color: AppTheme.textFaint)),
      );
    }
    return PageBody(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle("Sellers near you"),
          const SizedBox(height: 8),
          for (final s in _sellers) _sellerCard(s as Map),
        ],
      ),
    );
  }

  Widget _sellerCard(Map seller) {
    final products = _productsOf(seller["id"]);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Theme(
        // Remove the default ExpansionTile divider lines for a cleaner card.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const CircleAvatar(
            backgroundColor: AppTheme.cardGreen,
            child: Icon(Icons.storefront, color: AppTheme.lightGreen),
          ),
          title: Text(seller["name"] ?? "Seller"),
          subtitle: Text(
            products.isEmpty
                ? (seller["email"] ?? "")
                : "${products.length} product(s) available",
            style: const TextStyle(color: AppTheme.textFaint),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          children: products.isEmpty
              ? const [
                  ListTile(
                    dense: true,
                    title: Text("No products in stock right now.",
                        style: TextStyle(color: AppTheme.textFaint)),
                  )
                ]
              : [for (final p in products) _productRow(p as Map)],
        ),
      ),
    );
  }

  Widget _productRow(Map p) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: const Icon(Icons.inventory_2, color: AppTheme.lightGreen),
        title: Text(p["name"] ?? "Product"),
        subtitle: Text("${p["type"]} • in stock: ${p["stock"]}",
            style: const TextStyle(color: AppTheme.textFaint)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("৳${p["price"]}",
                style: const TextStyle(
                    color: AppTheme.deepAmber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            FilledButton(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => _order(p),
              child: const Text("Order"),
            ),
          ],
        ),
      );

  Widget _ordersSection() {
    return PageBody(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          SectionTitle("My orders (${_orders.length})"),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const Text("You haven't placed any orders yet.",
                style: TextStyle(color: AppTheme.textFaint))
          else
            for (final o in _orders) _orderCard(o as Map),
        ],
      ),
    );
  }

  Widget _orderCard(Map o) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.receipt_long, color: AppTheme.lightGreen),
          title: Text(_productName(o["product_id"])),
          subtitle: Text("Order #${o["id"]} • quantity: ${o["quantity"]}",
              style: const TextStyle(color: AppTheme.textFaint)),
          trailing: _statusChip("${o["status"]}"),
        ),
      );

  Widget _statusChip(String status) {
    Color color = switch (status) {
      "delivered" => AppTheme.primaryGreen,
      "shipped" => AppTheme.lightGreen,
      "confirmed" => AppTheme.deepAmber,
      "cancelled" => AppTheme.danger,
      _ => AppTheme.textFaint,
    };
    return Chip(
      label: Text(status,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Quantity picker shown before placing an order.
class _OrderDialog extends StatefulWidget {
  final Map product;
  const _OrderDialog({required this.product});
  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final stock = (widget.product["stock"] as num?)?.toInt() ?? 1;
    final price = (widget.product["price"] as num?)?.toDouble() ?? 0;
    return AlertDialog(
      title: Text("Order ${widget.product["name"]}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Quantity"),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  ),
                  Text("$_qty", style: const TextStyle(fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _qty < stock ? () => setState(() => _qty++) : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text("Total: ৳${(price * _qty).toStringAsFixed(0)}",
                style: const TextStyle(
                    color: AppTheme.deepAmber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        FilledButton(
            onPressed: () => Navigator.pop(context, _qty),
            child: const Text("Place order")),
      ],
    );
  }
}
