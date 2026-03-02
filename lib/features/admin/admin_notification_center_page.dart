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
      'body': 'Platform will be offline for 2 hours tonight for upgrades.',
      'type': 'Broadcast',
      'status': 'Delivered',
      'recipients': 'All Users',
    },
    {
      'time': '09:00 AM',
      'title': 'Automated Handover Reminder',
      'body': 'Don\'t forget your scheduled handover at the Library.',
      'type': 'System',
      'status': 'Sent (42)',
      'recipients': 'Active Buyers',
    },
    {
      'time': 'Yesterday',
      'title': 'Welcome to CampusThrift',
      'body': 'Welcome to the platform! Start listing your items today.',
      'type': 'System',
      'status': 'Sent (15)',
      'recipients': 'New Users',
    },
  ];

  String _selectedFilter = 'All';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth > 1000;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 32),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _buildComposeSection()),
                      const SizedBox(width: 32),
                      Expanded(flex: 6, child: _buildLogsSection()),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildComposeSection(),
                      const SizedBox(height: 32),
                      _buildLogsSection(),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notification Center',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage system broadcasts and track automated notifications.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildComposeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.campaign_rounded, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Text(
                'Compose Broadcast',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Notification Title',
              hintText: 'e.g. Server Maintenance',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Message Body',
              hintText: 'Details about the announcement...',
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _handleSubmit(context),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send to All Users'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This will send a push notification to all 1,245 registered users immediately.',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.black38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    final filteredLogs = _selectedFilter == 'All'
        ? _logs
        : _logs.where((log) => log['type'] == _selectedFilter).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Activity Log',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              _buildFilterChips(),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No logs found for this category.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredLogs.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 32, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final log = filteredLogs[index];
                final bool isSystem = log['type'] == 'System';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isSystem
                          ? Colors.purple.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.1),
                      child: Icon(
                        isSystem ? Icons.auto_awesome : Icons.campaign_rounded,
                        color: isSystem ? Colors.purple : Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  log['title']?.toString() ?? 'No Title',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                log['time']?.toString() ?? 'Unknown Time',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log['body']?.toString() ??
                                'No message body provided.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildBadge(
                                log['status']?.toString() ?? 'Status Unknown',
                                Colors.green,
                              ),
                              _buildBadge(
                                log['recipients']?.toString() ?? 'All',
                                Colors.grey,
                              ),
                              // Remove Spacer when using Wrap, or use a custom layout
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text('View Analytics'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['All', 'System', 'Broadcast'].map((filter) {
          final bool isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              backgroundColor: Colors.grey.shade50,
              selectedColor: Colors.blue.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide(
                color: isSelected ? Colors.blue : Colors.grey.shade200,
                width: 1,
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _handleSubmit(BuildContext context) {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both title and body.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Broadcast'),
        content: Text(
          'Sending "${_titleController.text}" to ALL users. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _processSend();
            },
            child: const Text('Confirm & Send'),
          ),
        ],
      ),
    );
  }

  void _processSend() {
    setState(() {
      _logs.insert(0, {
        'time': 'Just now',
        'title': _titleController.text,
        'body': _bodyController.text,
        'type': 'Broadcast',
        'status': 'Processing...',
        'recipients': 'All Users',
      });
      _titleController.clear();
      _bodyController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Broadcast queued successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
