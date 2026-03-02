import 'package:flutter/material.dart';

class AdminListingModerationPage extends StatefulWidget {
  const AdminListingModerationPage({super.key});

  @override
  State<AdminListingModerationPage> createState() =>
      _AdminListingModerationPageState();
}

class _AdminListingModerationPageState
    extends State<AdminListingModerationPage> {
  final List<Map<String, dynamic>> _listings = [
    {
      'title': 'Calculus 101 Textbook',
      'seller': 'Alice Smith',
      'price': '\$25.00',
      'status': 'Active',
      'reported': false,
    },
    {
      'title': 'MacBook Pro 2020',
      'seller': 'Bob Johnson',
      'price': '\$800.00',
      'status': 'Under Review',
      'reported': true,
    },
    {
      'title': 'Dorm Desk Lamp',
      'seller': 'Charlie Davis',
      'price': '\$10.00',
      'status': 'Active',
      'reported': false,
    },
    {
      'title': 'Fake Tickets',
      'seller': 'Diana Prince',
      'price': '\$150.00',
      'status': 'Active',
      'reported': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listing Moderation',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Manage all active listings on the platform. Flag or remove inappropriate items.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _listings.length,
                  itemBuilder: (context, index) {
                    final item = _listings[index];
                    return _buildListingCard(item, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> item, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: item['reported']
            ? Border.all(color: Colors.orange, width: 2)
            : Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_rounded,
                  size: 64,
                  color: Colors.black26,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item['reported'])
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Flagged for Review',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  item['title'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seller: ${item['seller']}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  item['price'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _confirmFlag(item['title'], index),
                      icon: const Icon(
                        Icons.flag_rounded,
                        size: 18,
                        color: Colors.orange,
                      ),
                      label: const Text(
                        'Flag',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(item['title'], index),
                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
                      tooltip: 'Delete Listing',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String title, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text(
          'Are you sure you want to permanently delete "$title"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _listings.removeAt(index));
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Listing deleted.')));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmFlag(String title, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flag Listing'),
        content: Text(
          'Mark "$title" as requiring manual review? It will be hidden from search results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              setState(() => _listings[index]['reported'] = true);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Listing flagged for review.')),
              );
            },
            child: const Text('Flag Item'),
          ),
        ],
      ),
    );
  }
}
