import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/state.dart';

class AdminFraudDetectionPage extends StatefulWidget {
  const AdminFraudDetectionPage({super.key});

  @override
  State<AdminFraudDetectionPage> createState() =>
      _AdminFraudDetectionPageState();
}

class _AdminFraudDetectionPageState extends State<AdminFraudDetectionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminFraudState>().scanSuspiciousUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompactLayout = MediaQuery.of(context).size.width < 420;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Consumer<AdminFraudState>(
          builder: (context, fraudState, child) {
            final flags = fraudState.flags;

            return RefreshIndicator(
              onRefresh: () async {
                await context.read<AdminFraudState>().scanSuspiciousUsers();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isCompactLayout ? 16 : 24),
                children: [
                  Text(
                    'Fraud Detection',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review suspicious users flagged from listing bursts and repeated messages.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
                  ),
                  if (fraudState.isLoading) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(minHeight: 5),
                    ),
                  ],
                  if (fraudState.error != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBanner(fraudState.error!),
                  ],
                  const SizedBox(height: 16),
                  if (flags.isEmpty)
                    _buildEmptyState(context)
                  else
                    _buildFlagsContainer(flags),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagsContainer(List<FraudFlagModel> flags) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(flags.length, (index) {
          final flag = flags[index];
          return Column(
            children: [
              _buildFlagTile(flag),
              if (index != flags.length - 1) const Divider(height: 1),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFlagTile(FraudFlagModel flag) {
    final riskColor = _riskColor(flag.riskScore);

    return InkWell(
      onTap: () => _showFlagDetails(flag),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: riskColor.withValues(alpha: 0.15),
              child: Text(
                flag.userName.isNotEmpty ? flag.userName[0].toUpperCase() : '?',
                style: TextStyle(color: riskColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          flag.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Risk ${flag.riskScore}',
                          style: TextStyle(
                            color: riskColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    flag.userEmail,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMetaChip(
                        label: 'Listings ${flag.listingsCreatedLast24Hours}',
                      ),
                      _buildMetaChip(
                        label:
                            'Repeated messages ${flag.repeatedMessageBurstCount}',
                      ),
                    ],
                  ),
                  if (flag.reasons.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Reasons: ${flag.reasons.join(' | ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (flag.repeatedMessageSample != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sample: "${flag.repeatedMessageSample}"',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right_rounded, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showFlagDetails(FraudFlagModel flag) {
    final listings = [...flag.suspiciousListings];
    final hasListings = listings.isNotEmpty;
    final hasRepeatedMessages = flag.repeatedMessageBurstCount > 0;
    listings.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) {
        return a.title.compareTo(b.title);
      }
      if (aTime == null) {
        return 1;
      }
      if (bTime == null) {
        return -1;
      }
      return bTime.compareTo(aTime);
    });

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flag.userName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasListings && hasRepeatedMessages
                            ? 'Suspicious activity detected in the last 24 hours'
                            : hasListings
                            ? 'Suspicious listings created in the last 24 hours'
                            : 'Repeated message activity detected in the last 24 hours',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      if (hasRepeatedMessages) ...[
                        const Text(
                          'Repeated messages',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF3F4F6),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sent the same message ${flag.repeatedMessageBurstCount} times within 24 hours.',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                              if (flag.repeatedMessageSample != null &&
                                  flag.repeatedMessageSample!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Sample: "${flag.repeatedMessageSample}"',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (hasListings) ...[
                        if (hasRepeatedMessages) const SizedBox(height: 20),
                        const Text(
                          'Suspicious listings',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(listings.length, (index) {
                          final listing = listings[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == listings.length - 1 ? 0 : 12,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFF3F4F6),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    listing.title.isNotEmpty
                                        ? listing.title
                                        : 'Untitled listing',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Created: ${listing.createdAt != null ? _formatTimestamp(listing.createdAt!) : 'Unknown date'}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                      if (!hasListings && !hasRepeatedMessages)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'No suspicious activity details are available for this user.',
                            style: TextStyle(
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_rounded,
            size: 32,
            color: Color(0xFF059669),
          ),
          const SizedBox(height: 12),
          Text(
            'No suspicious users detected',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The latest 24-hour scan did not find any unusual listing bursts or repeated message patterns.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Color _riskColor(int riskScore) {
    if (riskScore >= 70) {
      return const Color(0xFFB91C1C);
    }
    return const Color(0xFFD97706);
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} ${local.hour}:$minute';
  }
}
