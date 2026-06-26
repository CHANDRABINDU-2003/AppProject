import 'package:flutter/material.dart';
import 'package:agripulse/theme/app_theme.dart';
import 'package:agripulse/shared/services/api_service.dart';
import 'package:agripulse/shared/widgets/common.dart';

/// Seller catalogue — list of the seller's products with an "add product" FAB.
class SellerProductsPage extends StatefulWidget {
  const SellerProductsPage({super.key});

  @override
  State<SellerProductsPage> createState() => _SellerProductsPageState();
}

class _SellerProductsPageState extends State<SellerProductsPage> {
  final _api = ApiService.instance;
  List<dynamic> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _products = await _api.get("/seller/products");
    } catch (e) {
      if (mounted) showResultDialog(context, "Error", "$e");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addProduct() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add product"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
            TextField(
                controller: price,
                decoration: const InputDecoration(labelText: "Price"),
                keyboardType: TextInputType.number),
            TextField(
                controller: stock,
                decoration: const InputDecoration(labelText: "Stock"),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              await _api.post("/seller/products", {
                "name": name.text,
                "type": "fertilizer",
                "price": double.tryParse(price.text) ?? 0,
                "stock": int.tryParse(stock.text) ?? 0,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add),
        label: const Text("Add product"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  const PageBody(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: PageHeader("My products",
                        subtitle: "Everything in your catalogue."),
                  ),
                  if (_products.isEmpty)
                    const PageBody(
                      child: Text("No products yet — tap “Add product”.",
                          style: TextStyle(color: AppTheme.textFaint)),
                    )
                  else
                    for (final p in _products)
                      PageBody(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppTheme.surfaceWhite,
                              child: Icon(Icons.inventory_2, color: AppTheme.lightGreen),
                            ),
                            title: Text(p["name"] ?? "Product"),
                            subtitle: Text("${p["type"]} • stock: ${p["stock"]}"),
                            trailing: Text("৳${p["price"]}",
                                style: const TextStyle(
                                    color: AppTheme.deepAmber, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
