class ProductModel {
  final String id;
  final String name;
  final double price;
  final int stock;

  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
  });

  ProductModel copyWith({
    String? id,
    String? name,
    double? price,
    int? stock,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'stock': stock,
      };

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        stock: json['stock'] as int? ?? 0,
      );
}

class SelectedItemModel {
  final String id;
  final String name;
  final double price;
  final int qty;

  const SelectedItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
  });

  double get totalValue => price * qty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'qty': qty,
      };

  factory SelectedItemModel.fromJson(Map<String, dynamic> json) => SelectedItemModel(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        qty: json['qty'] as int,
      );
}
