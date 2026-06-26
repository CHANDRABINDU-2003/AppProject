import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Marketplace — farmers browse seller products and place orders.
///
/// Two tabs: **Shop** (all in-stock products, tap to order) and **My Orders**
/// (the farmer's order history with status). Backed by `/marketplace/*`.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _api = ApiService.instance;

  List<dynamic> _products = [];
  List<dynamic> _orders = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _api.get("/marketplace/products");
      final orders = await _api.get("/marketplace/orders");
      if (!mounted) return;
      setState(() {
        _products = products;
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
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
        SnackBar(content: Text("Order placed for $qty × ${product["name"]}")),
      );
      _load(); // refresh stock + orders
    } catch (e) {
      if (mounted) showResultDialog(context, "Could not place order", "$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        // The shell owns the top bar; the Shop/Orders tabs live in the body.
        body: Column(
          children: [
            const Material(
              color: AppTheme.surfaceWhite,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: AppTheme.primaryGreen,
                    labelColor: AppTheme.primaryGreen,
                    unselectedLabelColor: AppTheme.textFaint,
                    tabs: [Tab(text: "Shop"), Tab(text: "My Orders")],
                  ),
                  Divider(height: 1, thickness: 1),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _errorView()
                      : TabBarView(children: [_shopTab(), _ordersTab()]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppTheme.accentYellow),
              const SizedBox(height: 12),
              Text("Couldn't load marketplace.\n$_error",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textFaint)),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry")),
            ],
          ),
        ),
      );

  Widget _shopTab() {
    if (_products.isEmpty) {
      return const Center(
        child: Text("No products available right now.",
            style: TextStyle(color: AppTheme.textFaint)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _products.length,
        itemBuilder: (_, i) {
          final p = _products[i] as Map;
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.cardGreen,
                child: Icon(Icons.inventory_2, color: AppTheme.lightGreen),
              ),
              title: Text(p["name"] ?? "Product"),
              subtitle: Text("${p["type"]} • in stock: ${p["stock"]}",
                  style: const TextStyle(color: AppTheme.textFaint)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("৳${p["price"]}",
                      style: const TextStyle(
                          color: AppTheme.accentYellow,
                          fontWeight: FontWeight.bold)),
                  const Text("Tap to order",
                      style: TextStyle(fontSize: 11, color: AppTheme.lightGreen)),
                ],
              ),
              onTap: () => _order(p),
            ),
          );
        },
      ),
    );
  }

  Widget _ordersTab() {
    if (_orders.isEmpty) {
      return const Center(
        child: Text("You haven't placed any orders yet.",
            style: TextStyle(color: AppTheme.textFaint)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _orders.length,
        itemBuilder: (_, i) {
          final o = _orders[i] as Map;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: AppTheme.lightGreen),
              title: Text("Order #${o["id"]}"),
              subtitle: Text("Quantity: ${o["quantity"]}",
                  style: const TextStyle(color: AppTheme.textFaint)),
              trailing: Chip(label: Text("${o["status"]}")),
            ),
          );
        },
      ),
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
    return AlertDialog(
      title: Text("Order ${widget.product["name"]}"),
      content: Row(
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
