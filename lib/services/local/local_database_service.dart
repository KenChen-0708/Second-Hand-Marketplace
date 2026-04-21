import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';

class LocalDatabaseService {
  LocalDatabaseService._();

  static final LocalDatabaseService instance = LocalDatabaseService._();

  static const _databaseName = 'marketplace_cache.db';
  static const _databaseVersion = 3;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);
    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createProductsTable(db);
    await _createUserProfilesTable(db);
    await _createCartItemsTable(db);
    await _createWishlistItemsTable(db);
    await _createChatConversationsTable(db);
    await _createChatMessagesTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createUserProfilesTable(db);
    }
    await _ensureSchema(db);
  }

  Future<void> _onOpen(Database db) async {
    await _ensureSchema(db);
  }

  Future<void> _ensureSchema(Database db) async {
    await _createProductsTable(db);
    await _createUserProfilesTable(db);
    await _createCartItemsTable(db);
    await _createWishlistItemsTable(db);
    await _createChatConversationsTable(db);
    await _createChatMessagesTable(db);
    await _ensureCartVariantColumn(db);
  }

  Future<void> _ensureCartVariantColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(cart_items)');
    final hasVariantId = columns.any((column) => column['name'] == 'variant_id');
    if (!hasVariantId) {
      await db.execute('ALTER TABLE cart_items ADD COLUMN variant_id TEXT');
    }
  }

  Future<void> _createProductsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        category_id TEXT,
        condition TEXT,
        seller_id TEXT,
        status TEXT,
        price REAL,
        search_text TEXT,
        data TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        last_synced_at TEXT
      )
    ''');
  }

  Future<void> _createUserProfilesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profiles (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createCartItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        variant_id TEXT,
        quantity INTEGER NOT NULL,
        added_at TEXT,
        product_data TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cart_items_user_status ON cart_items(user_id, sync_status, is_deleted)',
    );
  }

  Future<void> _createWishlistItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wishlist_items (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        created_at TEXT,
        product_data TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wishlist_items_user_status ON wishlist_items(user_id, sync_status, is_deleted)',
    );
  }

  Future<void> _createChatConversationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_conversations (
        id TEXT PRIMARY KEY,
        current_user_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        other_user_id TEXT NOT NULL,
        other_user_name TEXT,
        conversation_data TEXT NOT NULL,
        product_data TEXT NOT NULL,
        other_user_data TEXT NOT NULL,
        last_message_at TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_conversations_user ON chat_conversations(current_user_id, last_message_at)',
    );
  }

  Future<void> _createChatMessagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        message_text TEXT NOT NULL,
        is_image INTEGER NOT NULL,
        image_url TEXT,
        is_read INTEGER NOT NULL,
        created_at TEXT,
        data TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation ON chat_messages(conversation_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_messages_sync ON chat_messages(sync_status, created_at)',
    );
  }

  Future<void> cacheProducts(List<ProductModel> products) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toUtc().toIso8601String();

    for (final product in products) {
      batch.insert(
        'products',
        {
          'id': product.id,
          'title': product.title,
          'description': product.description,
          'category_id': product.categoryId,
          'condition': product.condition,
          'seller_id': product.sellerId,
          'status': product.status,
          'price': product.price,
          'search_text': _productSearchText(product),
          'data': product.toJson(),
          'created_at': product.createdAt?.toIso8601String(),
          'updated_at': product.updatedAt?.toIso8601String(),
          'last_synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> cacheProduct(ProductModel product) async {
    await cacheProducts([product]);
  }

  Future<void> cacheUserProfile(UserModel user) async {
    final db = await database;
    await db.insert(
      'user_profiles',
      {
        'id': user.id,
        'email': user.email,
        'data': user.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> getCachedUserProfileByEmail(String email) async {
    final db = await database;
    final rows = await db.query(
      'user_profiles',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return UserModel.fromJson(rows.first['data'] as String);
  }

  Future<UserModel?> getCachedUserProfileById(String userId) async {
    final db = await database;
    final rows = await db.query(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return UserModel.fromJson(rows.first['data'] as String);
  }

  Future<List<ProductModel>> getCachedProducts({
    String? status,
    String? sellerId,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (status != null && status.isNotEmpty) {
      whereParts.add('status = ?');
      whereArgs.add(status);
    }

    if (sellerId != null && sellerId.isNotEmpty) {
      whereParts.add('seller_id = ?');
      whereArgs.add(sellerId);
    }

    final rows = await db.query(
      'products',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'datetime(created_at) DESC',
    );

    return rows
        .map((row) => ProductModel.fromJson(row['data'] as String))
        .toList();
  }

  Future<List<ProductModel>> searchCachedProducts({
    required String query,
    String? status,
  }) async {
    final db = await database;
    final normalizedQuery = query.trim().toLowerCase();
    final whereParts = <String>['search_text LIKE ?'];
    final whereArgs = <Object?>['%$normalizedQuery%'];

    if (status != null && status.isNotEmpty) {
      whereParts.add('status = ?');
      whereArgs.add(status);
    }

    final rows = await db.query(
      'products',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'datetime(created_at) DESC',
    );

    return rows
        .map((row) => ProductModel.fromJson(row['data'] as String))
        .toList();
  }

  Future<ProductModel?> getCachedProductById(String productId) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return ProductModel.fromJson(rows.first['data'] as String);
  }

  Future<void> replaceCartItems(String userId, List<CartModel> items) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toUtc().toIso8601String();

    batch.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
    for (final item in items) {
      batch.insert(
        'cart_items',
        {
          'id': _cartKey(userId, item.product.id, item.selectedVariant?.id),
          'user_id': userId,
          'product_id': item.product.id,
          'variant_id': item.selectedVariant?.id,
          'quantity': item.quantity,
          'added_at': item.addedAt?.toIso8601String(),
          'product_data': item.product.toJson(),
          'sync_status': 'synced',
          'is_deleted': 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<CartModel>> getCachedCartItems(String userId) async {
    final db = await database;
    final rows = await db.query(
      'cart_items',
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'datetime(added_at) ASC',
    );

    return rows.map((row) {
      return CartModel(
        id: row['id'] as String,
        product: ProductModel.fromJson(row['product_data'] as String),
        selectedVariant: _selectedVariantFromRow(row),
        quantity: row['quantity'] as int,
        addedAt: row['added_at'] == null
            ? null
            : DateTime.tryParse(row['added_at'] as String),
      );
    }).toList();
  }

  Future<void> upsertCartItem({
    required String userId,
    required ProductModel product,
    ProductVariationModel? selectedVariant,
    required int quantity,
    DateTime? addedAt,
    String syncStatus = 'pending',
  }) async {
    final db = await database;
    await db.insert(
      'cart_items',
      {
        'id': _cartKey(userId, product.id, selectedVariant?.id),
        'user_id': userId,
        'product_id': product.id,
        'variant_id': selectedVariant?.id,
        'quantity': quantity,
        'added_at': (addedAt ?? DateTime.now()).toIso8601String(),
        'product_data': product.toJson(),
        'sync_status': syncStatus,
        'is_deleted': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markCartItemDeleted({
    required String userId,
    required String productId,
    String? variantId,
  }) async {
    final db = await database;
    await db.update(
      'cart_items',
      {
        'is_deleted': 1,
        'sync_status': 'pending_delete',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [_cartKey(userId, productId, variantId)],
    );
  }

  Future<void> deleteCartItemPermanently({
    required String userId,
    required String productId,
    String? variantId,
  }) async {
    final db = await database;
    await db.delete(
      'cart_items',
      where: 'id = ?',
      whereArgs: [_cartKey(userId, productId, variantId)],
    );
  }

  Future<void> clearCartLocally(String userId, {bool markForSync = true}) async {
    final db = await database;
    if (markForSync) {
      await db.update(
        'cart_items',
        {
          'is_deleted': 1,
          'sync_status': 'pending_delete',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return;
    }

    await db.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<List<Map<String, dynamic>>> getPendingCartRows(String userId) async {
    final db = await database;
    final rows = await db.query(
      'cart_items',
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'synced'],
      orderBy: 'datetime(updated_at) ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> replaceWishlistItems(
    String userId,
    List<WishlistItemModel> items,
  ) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toUtc().toIso8601String();

    batch.delete('wishlist_items', where: 'user_id = ?', whereArgs: [userId]);
    for (final item in items) {
      batch.insert(
        'wishlist_items',
        {
          'id': _wishlistKey(userId, item.product.id),
          'user_id': userId,
          'product_id': item.product.id,
          'created_at': item.favorite.createdAt?.toIso8601String(),
          'product_data': item.product.toJson(),
          'sync_status': 'synced',
          'is_deleted': 0,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<WishlistItemModel>> getCachedWishlistItems(String userId) async {
    final db = await database;
    final rows = await db.query(
      'wishlist_items',
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'datetime(created_at) DESC',
    );

    return rows.map((row) {
      final product = ProductModel.fromJson(row['product_data'] as String);
      final createdAt = row['created_at'] == null
          ? null
          : DateTime.tryParse(row['created_at'] as String);
      final favorite = FavoriteModel(
        id: row['id'] as String,
        userId: userId,
        productId: product.id,
        createdAt: createdAt,
      );
      return WishlistItemModel(favorite: favorite, product: product);
    }).toList();
  }

  Future<void> upsertWishlistItem({
    required String userId,
    required ProductModel product,
    DateTime? createdAt,
    String syncStatus = 'pending',
  }) async {
    final db = await database;
    await db.insert(
      'wishlist_items',
      {
        'id': _wishlistKey(userId, product.id),
        'user_id': userId,
        'product_id': product.id,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'product_data': product.toJson(),
        'sync_status': syncStatus,
        'is_deleted': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markWishlistItemDeleted({
    required String userId,
    required String productId,
  }) async {
    final db = await database;
    await db.update(
      'wishlist_items',
      {
        'is_deleted': 1,
        'sync_status': 'pending_delete',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [_wishlistKey(userId, productId)],
    );
  }

  Future<void> deleteWishlistItemPermanently({
    required String userId,
    required String productId,
  }) async {
    final db = await database;
    await db.delete(
      'wishlist_items',
      where: 'id = ?',
      whereArgs: [_wishlistKey(userId, productId)],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingWishlistRows(String userId) async {
    final db = await database;
    final rows = await db.query(
      'wishlist_items',
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'synced'],
      orderBy: 'datetime(updated_at) ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> replaceConversationBundles(
    String currentUserId,
    List<Map<String, dynamic>> bundles,
  ) async {
    final db = await database;
    final batch = db.batch();
    batch.delete(
      'chat_conversations',
      where: 'current_user_id = ?',
      whereArgs: [currentUserId],
    );

    for (final bundle in bundles) {
      batch.insert(
        'chat_conversations',
        {
          'id': bundle['conversation_id'],
          'current_user_id': currentUserId,
          'product_id': bundle['product_id'],
          'other_user_id': bundle['other_user_id'],
          'other_user_name': bundle['other_user_name'],
          'conversation_data': bundle['conversation_data'],
          'product_data': bundle['product_data'],
          'other_user_data': bundle['other_user_data'],
          'last_message_at': bundle['last_message_at'],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> upsertConversationBundle(
    String currentUserId,
    Map<String, dynamic> bundle,
  ) async {
    final db = await database;
    await db.insert(
      'chat_conversations',
      {
        'id': bundle['conversation_id'],
        'current_user_id': currentUserId,
        'product_id': bundle['product_id'],
        'other_user_id': bundle['other_user_id'],
        'other_user_name': bundle['other_user_name'],
        'conversation_data': bundle['conversation_data'],
        'product_data': bundle['product_data'],
        'other_user_data': bundle['other_user_data'],
        'last_message_at': bundle['last_message_at'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCachedConversationRow(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'chat_conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getCachedConversationRows(
    String currentUserId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'chat_conversations',
      where: 'current_user_id = ?',
      whereArgs: [currentUserId],
      orderBy: 'datetime(last_message_at) DESC, id DESC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> replaceConversationMessages(
    String conversationId,
    List<ChatMessageModel> messages,
  ) async {
    final db = await database;
    final batch = db.batch();
    batch.delete(
      'chat_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );

    for (final message in messages) {
      batch.insert(
        'chat_messages',
        {
          'id': message.id,
          'conversation_id': message.conversationId,
          'sender_id': message.senderId,
          'message_text': message.messageText,
          'is_image': message.isImage ? 1 : 0,
          'image_url': message.imageUrl,
          'is_read': message.isRead ? 1 : 0,
          'created_at': message.createdAt?.toIso8601String(),
          'data': message.toJson(),
          'sync_status': 'synced',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> upsertChatMessage(
    ChatMessageModel message, {
    String syncStatus = 'synced',
  }) async {
    final db = await database;
    await db.insert(
      'chat_messages',
      {
        'id': message.id,
        'conversation_id': message.conversationId,
        'sender_id': message.senderId,
        'message_text': message.messageText,
        'is_image': message.isImage ? 1 : 0,
        'image_url': message.imageUrl,
        'is_read': message.isRead ? 1 : 0,
        'created_at': message.createdAt?.toIso8601String(),
        'data': message.toJson(),
        'sync_status': syncStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessageModel>> getCachedMessages(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'chat_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'datetime(created_at) ASC, id ASC',
    );

    return rows
        .map((row) => ChatMessageModel.fromJson(row['data'] as String))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPendingChatMessageRows() async {
    final db = await database;
    final rows = await db.query(
      'chat_messages',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'datetime(created_at) ASC, id ASC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> markMessageSynced({
    required String localMessageId,
    required ChatMessageModel remoteMessage,
  }) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('chat_messages', where: 'id = ?', whereArgs: [localMessageId]);
    batch.insert(
      'chat_messages',
      {
        'id': remoteMessage.id,
        'conversation_id': remoteMessage.conversationId,
        'sender_id': remoteMessage.senderId,
        'message_text': remoteMessage.messageText,
        'is_image': remoteMessage.isImage ? 1 : 0,
        'image_url': remoteMessage.imageUrl,
        'is_read': remoteMessage.isRead ? 1 : 0,
        'created_at': remoteMessage.createdAt?.toIso8601String(),
        'data': remoteMessage.toJson(),
        'sync_status': 'synced',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }

  String _productSearchText(ProductModel product) {
    return [
      product.title,
      product.description,
      product.condition,
      product.categoryId ?? '',
      product.sellerName ?? '',
      ...product.variations.map((variation) => variation.attributeSummary),
    ].join(' ').toLowerCase();
  }

  ProductVariationModel? _selectedVariantFromRow(Map<String, Object?> row) {
    final variantId = row['variant_id'] as String?;
    if (variantId == null || variantId.isEmpty) {
      return null;
    }

    final product = ProductModel.fromJson(row['product_data'] as String);
    for (final variation in product.variations) {
      if (variation.id == variantId) {
        return variation;
      }
    }
    return null;
  }

  static String _cartKey(String userId, String productId, [String? variantId]) =>
      '${userId}_${productId}_${variantId ?? 'default'}';
  static String _wishlistKey(String userId, String productId) =>
      '${userId}_$productId';
}
