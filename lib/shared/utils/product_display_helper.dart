import '../../models/product_model.dart';

class ProductDisplayHelper {
  ProductDisplayHelper._();

  static String formatTradePreference(String tradePreference) {
    switch (tradePreference) {
      case 'face_to_face':
        return 'Meet Up';
      case 'delivery_official':
        return 'Official Delivery';
      case 'delivery_self':
        return 'Self Delivery';
      default:
        return tradePreference
            .split('_')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
    }
  }

  static bool isVisibleToUser(ProductModel product, String? currentUserId) {
    if (product.status.toLowerCase() != 'active') {
      return false;
    }

    if (currentUserId != null &&
        currentUserId.isNotEmpty &&
        product.sellerId == currentUserId) {
      return false;
    }

    return !product.isSoldOut;
  }
}
