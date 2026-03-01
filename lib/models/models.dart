
class User {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });
}

class Product {
  final String id;
  final String title;
  final double price;
  final String condition;
  final String category;
  final String description;
  final String imageUrl;
  final User seller;

  Product({
    required this.id,
    required this.title,
    required this.price,
    required this.condition,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.seller,
  });
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime date;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    this.isRead = false,
  });
}

// Mock Data

final mockUser = User(
  id: 'u1',
  name: 'Alex Johnson',
  email: 'alex.j@student.university.edu',
  avatarUrl: 'https://i.pravatar.cc/150?img=11',
);

final mockSeller1 = User(
  id: 'u2',
  name: 'Sarah Chen',
  email: 'schen@student.university.edu',
  avatarUrl: 'https://i.pravatar.cc/150?img=5',
);

final mockSeller2 = User(
  id: 'u3',
  name: 'Mike Smith',
  email: 'msmith@student.university.edu',
  avatarUrl: 'https://i.pravatar.cc/150?img=8',
);

final List<Product> mockProducts = [
  Product(
    id: 'p1',
    title: 'Calculus Early Transcendentals, 8th Ed',
    price: 45.0,
    condition: 'Like New',
    category: 'Textbooks',
    description:
        'Barely used calculus textbook. No highlights or markings. Perfect for MAT101.',
    imageUrl:
        'https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&q=80&w=800',
    seller: mockSeller1,
  ),
  Product(
    id: 'p2',
    title: 'Sony WH-1000XM4 Headphones',
    price: 180.0,
    condition: 'Good',
    category: 'Electronics',
    description:
        'Great noise-canceling headphones. Works perfectly. Small scratch on the right earcup.',
    imageUrl:
        'https://images.unsplash.com/photo-1618366712010-f4ae9c647dcb?auto=format&fit=crop&q=80&w=800',
    seller: mockSeller2,
  ),
  Product(
    id: 'p3',
    title: 'Mini Fridge - 3.2 cu ft',
    price: 65.0,
    condition: 'Acceptable',
    category: 'Dorm Gear',
    description:
        'Reliable mini fridge, perfect for dorms. Has a small freezer compartment.',
    imageUrl:
        'https://images.unsplash.com/photo-1584568694244-14fb0f49fe07?auto=format&fit=crop&q=80&w=800',
    seller: mockSeller1,
  ),
  Product(
    id: 'p4',
    title: 'iPad Pro 11" M1 128GB',
    price: 550.0,
    condition: 'Excellent',
    category: 'Electronics',
    description:
        'Always kept in a case. Screen protector applied since day one. Comes with charger.',
    imageUrl:
        'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=crop&q=80&w=800',
    seller: mockSeller2,
  ),
];

final List<NotificationItem> mockNotifications = [
  NotificationItem(
    id: 'n1',
    title: 'Order Delivered',
    message: 'Your order "Calculus Early Transcendentals" has been delivered.',
    date: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  NotificationItem(
    id: 'n2',
    title: 'Item Sold',
    message: 'Great news! Someone just bought your Mini Fridge.',
    date: DateTime.now().subtract(const Duration(hours: 2)),
    isRead: true,
  ),
  NotificationItem(
    id: 'n3',
    title: 'System Alert',
    message: 'Scheduled maintenance this Saturday from 2 AM to 4 AM.',
    date: DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
  ),
];
