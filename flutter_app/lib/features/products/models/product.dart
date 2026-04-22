// These models mirror the Go backend's JSON responses.
// The field names here must match exactly what the API returns.
import 'package:flutter/foundation.dart';

@immutable
class Category {
  final String id;
  final String name;
  final String? description;
  final int sortOrder;

  const Category({
    required this.id,
    required this.name,
    this.description,
    required this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

@immutable
class ProductVariant {
  final String id;
  final String productId;
  final String size;
  final int price;   // IDR, e.g. 185000
  final int stock;
  final String sku;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.size,
    required this.price,
    required this.stock,
    required this.sku,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        size: json['size'] as String,
        price: (json['price'] as num).toInt(),
        stock: json['stock'] as int,
        sku: json['sku'] as String? ?? '',
      );

  bool get isOutOfStock => stock == 0;
  bool get isLowStock => stock > 0 && stock <= 5;
}

@immutable
class Product {
  final String id;
  final String name;
  final String brand;
  final String categoryId;
  final Category? category;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final bool isFeatured;
  final bool isFavourite;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.categoryId,
    this.category,
    this.description,
    this.imageUrl,
    required this.isActive,
    required this.isFeatured,
    required this.isFavourite,
    required this.variants,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String,
        categoryId: json['category_id'] as String,
        category: json['category'] != null
            ? Category.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        isFeatured: json['is_featured'] as bool? ?? false,
        isFavourite: json['is_favourite'] as bool? ?? false,
        variants: (json['variants'] as List<dynamic>? ?? [])
            .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
            .toList(),
      );

  int get totalStock => variants.fold(0, (sum, v) => sum + v.stock);
  bool get isOutOfStock => totalStock == 0;
}