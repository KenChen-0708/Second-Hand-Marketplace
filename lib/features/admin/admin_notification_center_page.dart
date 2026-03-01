import 'package:flutter/material.dart';

class AdminNotificationCenterPage extends StatefulWidget {
  const AdminNotificationCenterPage({super.key});

  @override
  State<AdminNotificationCenterPage> createState() =>
      _AdminNotificationCenterPageState();
}

class _AdminNotificationCenterPageState
    extends State<AdminNotificationCenterPage> {
  final List<Map<String, dynamic>> _logs = [
    {
      'time': '10:45 AM',
      'title': 'System Maintenance',
      'type': 'Broadcast',
      'status': 'Delivered',
    },
    {
      'time': '09:00 AM',
      'title': 'Automated Handover Reminder',
      'type': 'System',
      'status': 'Delivered (42)',
    },
    {
      'time': 'Yesterday',
      'title': 'Welcome to CampusThrift',
      'type': 'System',
      'status': 'Delivered (15)',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Draft & Broadcast',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TextField(
                            decoration: InputDecoration(
                              labelText: 'Notification Title',
                              hintText:
                                  'e.g. Server Maintenance tonight at 11 PM',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const TextField(
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Message Body',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () {
                                _showBroadcastConfirmation(context);
                              },
                              icon: const Icon(Icons.campaign_rounded),
                              label: const Text('Send Broadcast to All Users'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Logs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: ListView.separated(
                          itemCount: _logs.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: log['type'] == 'System'
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                child: Icon(
                                  log['type'] == 'System'
                                      ? Icons.computer_rounded
                                      : Icons.campaign_rounded,
                                  color: log['type'] == 'System'
                                      ? Colors.blue
                                      : Colors.orange,
                                ),
                              ),
                              title: Text(
                                log['title'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('${log['type']} • ${log['time']}'),
                              trailing: Text(
                                log['status'],
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBroadcastConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Broadcast'),
        content: const Text(
          'Are you sure you want to send this push notification to ALL registered users?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _logs.insert(0, {
                  'time': 'Just now',
                  'title': 'Broadcast Message',
                  'type': 'Broadcast',
                  'status': 'Delivering...',
                });
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Broadcast queued for delivery.')),
              );
            },
            child: const Text('Send Now'),
          ),
        ],
      ),
    );
  }
}
