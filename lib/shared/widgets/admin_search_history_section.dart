import 'package:flutter/material.dart';

class AdminSearchHistorySection extends StatelessWidget {
  const AdminSearchHistorySection({
    super.key,
    required this.history,
    required this.onSelected,
    required this.onDeleted,
    required this.onClearAll,
  });

  final List<String> history;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onDeleted;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent searches',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onClearAll,
              child: const Text('Clear all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: history.map((entry) {
            return InputChip(
              label: Text(entry),
              onPressed: () => onSelected(entry),
              onDeleted: () => onDeleted(entry),
              deleteIcon: const Icon(Icons.close, size: 18),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Colors.black12),
            );
          }).toList(),
        ),
      ],
    );
  }
}
