// Fetches and caches the product list from the backend.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/product.dart';

// Fetches all active products
final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/products');
  final List<dynamic> data = response.data as List<dynamic>;
  return data
      .map((p) => Product.fromJson(p as Map<String, dynamic>))
      .toList();
});

// Fetches all categories
final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/categories');
  final List<dynamic> data = response.data as List<dynamic>;
  return data
      .map((c) => Category.fromJson(c as Map<String, dynamic>))
      .toList();
});

// Selected category filter — null means "show all"
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Filtered products based on selected category and search query
final filteredProductsProvider = Provider.autoDispose<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

  return productsAsync.whenData((products) {
    return products.where((p) {
      final matchesCategory = selectedCategory == null ||
          p.categoryId == selectedCategory;
      final matchesSearch = searchQuery.isEmpty ||
          p.name.toLowerCase().contains(searchQuery) ||
          p.brand.toLowerCase().contains(searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  });
});

// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');