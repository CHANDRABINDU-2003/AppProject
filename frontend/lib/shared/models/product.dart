class Product {
  final int id;
  final int sellerId;
  final String name;
  final String type;
  final double price;
  final int stock;
  final int? regionId;

  Product({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.type,
    required this.price,
    required this.stock,
    this.regionId,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j["id"],
        sellerId: j["seller_id"],
        name: j["name"],
        type: j["type"] ?? "",
        price: (j["price"] ?? 0).toDouble(),
        stock: j["stock"] ?? 0,
        regionId: j["region_id"],
      );
}
