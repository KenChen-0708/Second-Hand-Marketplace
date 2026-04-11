import '../models/product_model.dart';
import '../services/product/product_service.dart';
import 'entity_state.dart';

class ProductState extends EntityState<ProductModel> {
  ProductState({ProductService? productService})
    : _productService = productService ?? ProductService();

  final ProductService _productService;

  Future<List<ProductModel>> fetchProducts({String? status = 'active'}) async {
    setLoading(true);
    setError(null);

    try {
      final products = await _productService.fetchProducts(status: status);
      setItems(products);
      return products;
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<ProductModel?> fetchProductById(String productId) async {
    setLoading(true);
    setError(null);

    try {
      final product = await _productService.fetchProductById(productId);
      upsertItem(product);
      setSelectedItem(product);
      return product;
    } catch (e) {
      setError(e.toString());
      return getById(productId);
    } finally {
      setLoading(false);
    }
  }
  Future<void> deleteProduct(String productId) async {
    try {
      await _productService.deleteProduct(productId);
      removeById(productId);
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }
  Future<void> updateProduct(String productId, Map<String, dynamic> updateData) async {
    try {
      await _productService.updateProduct(productId, updateData);

      // Update local state if the item exists
      final existing = getById(productId);
      if (existing != null) {
        final updated = existing.copyWith(
          title: updateData['title'],
          description: updateData['description'],
          price: (updateData['price'] as num?)?.toDouble(),
          condition: updateData['condition'],
          status: updateData['status'],
          categoryId: updateData['category_id'],
          images: updateData['image_urls'] != null 
              ? List<String>.from(updateData['image_urls']) 
              : existing.images,
          imageUrl: (updateData['image_urls'] != null && (updateData['image_urls'] as List).isNotEmpty)
              ? (updateData['image_urls'] as List)[0]
              : existing.imageUrl,
          updatedAt: DateTime.now(),
        );
        upsertItem(updated);
        if (selectedItem?.id == productId) {
          setSelectedItem(updated);
        }
      }
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }
}
