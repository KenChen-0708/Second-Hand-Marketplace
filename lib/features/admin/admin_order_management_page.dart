import 'package:flutter/material.dart';

class AdminOrderManagementPage extends StatefulWidget {
  const AdminOrderManagementPage({super.key});

  @override
  State<AdminOrderManagementPage> createState() =>
      _AdminOrderManagementPageState();
}

class _AdminOrderManagementPageState extends State<AdminOrderManagementPage> {
  final List<Map<String, dynamic>> _orders = [
    {
      'id': '#ORD-4011',
      'buyer': 'Diana P.',
      'seller': 'Alice S.',
      'item': 'Calculus 101',
      'status': 'Pending',
    },
    {
      'id': '#ORD-4012',
      'buyer': 'Charlie D.',
      'seller': 'Bob J.',
      'item': 'Desk Lamp',
      'status': 'Paid',
    },
    {
      'id': '#ORD-4013',
      'buyer': 'Eve M.',
      'seller': 'Diana P.',
      'item': 'Economics Notes',
      'status': 'Handed Over',
    },
    {
      'id': '#ORD-4014',
      'buyer': 'Alice S.',
      'seller': 'Eve M.',
      'item': 'Bicycle',
      'status': 'Disputed',
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
                'Order Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Monitor transactions and resolve status disputes.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF9FAFB),
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Order ID',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Item',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Buyer',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Seller',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Current Status',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Actions',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: _orders.map((order) {
                          return DataRow(
                            cells: [
                              DataCell(Text(order['id'])),
                              DataCell(Text(order['item'])),
                              DataCell(Text(order['buyer'])),
                              DataCell(Text(order['seller'])),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      order['status'],
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    order['status'],
                                    style: TextStyle(
                                      color: _getStatusColor(order['status']),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                PopupMenuButton<String>(
                                  onSelected: (newStatus) {
                                    setState(() {
                                      order['status'] = newStatus;
                                    });
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'Pending',
                                      child: Text('Set: Pending'),
                                    ),
                                    PopupMenuItem(
                                      value: 'Paid',
                                      child: Text('Set: Paid'),
                                    ),
                                    PopupMenuItem(
                                      value: 'Handed Over',
                                      child: Text('Set: Handed Over'),
                                    ),
                                    PopupMenuItem(
                                      value: 'Cancelled',
                                      child: Text(
                                        'Set: Cancelled',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'Disputed',
                                      child: Text(
                                        'Set: Disputed',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                    ),
                                  ],
                                  icon: const Icon(Icons.edit_note_rounded),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.blue;
      case 'Paid':
        return Colors.teal;
      case 'Handed Over':
        return Colors.green;
      case 'Disputed':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
