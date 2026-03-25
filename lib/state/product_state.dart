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
}
