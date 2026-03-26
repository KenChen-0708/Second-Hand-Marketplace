/// Mock data for testing and development.
/// These are converted to align with the database schema models.
/// This file can be removed or replaced with real Supabase data when the backend is integrated.

import 'models.dart';

// ============= Mock Users =============

final mockUserBuyer = UserModel(
  id: 'u1',
  name: 'Alex Johnson',
  email: 'alex.j@student.university.edu',
  avatarUrl: 'https://i.pravatar.cc/150?img=11',
  role: 'user',
  isActive: true,
  createdAt: DateTime.now().subtract(const Duration(days: 90)),
  updatedAt: DateTime.now().subtract(const Duration(days: 5)),
);

final mockUserSeller1 = UserModel(
  id: 'u2',
  name: 'Sarah Chen',
  email: 'schen@student.university.edu',
  avatarUrl: 'https://i.pravatar.cc/150?img=5',
  role: 'user',
  isActive: true,
  createdAt: DateTime.now().subtract(const Duration(days: 120)),
  updatedAt: DateTime.now().subtract(const Duration(days: 2)),
);

final mockUserSeller2 = UserModel(
  id: 'u3',
  name: 'Mike Smith',
  email: 'msmith@student.university.edu',
  avatarUrl: 'https://i.pravatar.cc/150?img=8',
  role: 'user',
  isActive: true,
  createdAt: DateTime.now().subtract(const Duration(days: 60)),
  updatedAt: DateTime.now(),
);

// ============= Mock Categories =============

final mockCategories = [
  CategoryModel(
    id: 'cat1',
    name: 'Textbooks',
    description: 'Academic textbooks and course materials',
    createdAt: DateTime.now().subtract(const Duration(days: 365)),
  ),
  CategoryModel(
    id: 'cat2',
    name: 'Electronics',
    description: 'Phones, laptops, headphones, and gadgets',
    createdAt: DateTime.now().subtract(const Duration(days: 365)),
  ),
  CategoryModel(
    id: 'cat3',
    name: 'Furniture',
    description: 'Dorm and home furniture',
    createdAt: DateTime.now().subtract(const Duration(days: 365)),
  ),
];

// ============= Mock Products =============

final mockProducts = [
  ProductModel(
    id: 'p1',
    title: 'Calculus Early Transcendentals, 8th Ed',
    description: 'Barely used calculus textbook. No highlights or markings. Perfect for MAT101.',
    price: 45.0,
    categoryId: 'cat1',
    sellerId: 'u2',
    condition: 'Like New',
    imageUrl:
        'https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&q=80&w=800',
    status: 'active',
    viewCount: 12,
    likesCount: 3,
    createdAt: DateTime.now().subtract(const Duration(days: 15)),
    updatedAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  ProductModel(
    id: 'p2',
    title: 'Sony WH-1000XM4 Headphones',
    description: 'Great noise-canceling headphones. Works perfectly. Small scratch on the right earcup.',
    price: 180.0,
    categoryId: 'cat2',
    sellerId: 'u3',
    condition: 'Good',
    imageUrl:
        'https://images.unsplash.com/photo-1618366712010-f4ae9c647dcb?auto=format&fit=crop&q=80&w=800',
    status: 'active',
    viewCount: 48,
    likesCount: 9,
    createdAt: DateTime.now().subtract(const Duration(days: 20)),
    updatedAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  ProductModel(
    id: 'p3',
    title: 'Mechanical Keyboard - RGB Backlit',
    description:
        'Tactile mechanical keyboard with customizable RGB lighting. Perfect for gaming or late-night coding sessions.',
    price: 45.0,
    categoryId: 'cat2',
    sellerId: 'u2',
    condition: 'Excellent',
    imageUrl:
        'https://images.unsplash.com/photo-1511467687858-23d96c32e4ae?auto=format&fit=crop&q=80&w=800',
    status: 'active',
    viewCount: 35,
    likesCount: 7,
    createdAt: DateTime.now().subtract(const Duration(days: 8)),
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  ProductModel(
    id: 'p4',
    title: 'iPad Pro 11" M1 128GB',
    description: 'Always kept in a case. Screen protector applied since day one. Comes with charger.',
    price: 550.0,
    categoryId: 'cat2',
    sellerId: 'u3',
    condition: 'Excellent',
    imageUrl:
        'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=crop&q=80&w=800',
    status: 'active',
    viewCount: 89,
    likesCount: 22,
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
    updatedAt: DateTime.now(),
  ),
];

// ============= Mock Notifications =============

final mockNotifications = [
  AppNotificationModel(
    id: 'n1',
    userId: 'u1',
    title: 'Order Delivered',
    message: 'Your order "Calculus Early Transcendentals" has been delivered.',
    notificationType: 'order_status',
    relatedOrderId: 'o1',
    relatedProductId: 'p1',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  AppNotificationModel(
    id: 'n2',
    userId: 'u2',
    title: 'Item Sold',
    message: 'Great news! Someone just bought your Mechanical Keyboard.',
    notificationType: 'sale',
    relatedProductId: 'p3',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  AppNotificationModel(
    id: 'n3',
    userId: 'u1',
    title: 'System Alert',
    message: 'Scheduled maintenance this Saturday from 2 AM to 4 AM.',
    notificationType: 'system',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

// ============= Mock Orders =============

final mockOrders = [
  OrderModel(
    id: 'o1',
    orderNumber: '#CT-9921',
    buyerId: 'u1',
    totalPrice: 45.0,
    status: 'Pending',
    paymentStatus: 'Pending',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    orderItems: [
      OrderItemModel(
        id: 'oi1',
        orderId: 'o1',
        productId: 'p1',
        quantity: 1,
        unitPrice: 45.0,
        subtotal: 45.0,
      ),
    ],
  ),
  OrderModel(
    id: 'o2',
    orderNumber: '#CT-8832',
    buyerId: 'u1',
    totalPrice: 180.0,
    status: 'Completed',
    paymentStatus: 'Paid',
    handoverDate: DateTime.now().subtract(const Duration(days: 4)),
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    updatedAt: DateTime.now().subtract(const Duration(days: 4)),
    orderItems: [
      OrderItemModel(
        id: 'oi2',
        orderId: 'o2',
        productId: 'p2',
        quantity: 1,
        unitPrice: 180.0,
        subtotal: 180.0,
      ),
    ],
  ),
  OrderModel(
    id: 'o3',
    orderNumber: '#CT-7741',
    buyerId: 'u1',
    totalPrice: 45.0,
    status: 'Cancelled',
    paymentStatus: 'Pending',
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
    updatedAt: DateTime.now().subtract(const Duration(days: 10)),
    orderItems: [
      OrderItemModel(
        id: 'oi3',
        orderId: 'o3',
        productId: 'p3',
        quantity: 1,
        unitPrice: 45.0,
        subtotal: 45.0,
      ),
    ],
  ),
];

// ============= Mock Cart Items =============

final mockCartItems = [
  CartItemModel(
    id: 'ci1',
    userId: 'u1',
    productId: 'p2',
    quantity: 1,
    addedAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  CartItemModel(
    id: 'ci2',
    userId: 'u1',
    productId: 'p4',
    quantity: 2,
    addedAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
];
