import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/seller/seller_follow_service.dart';
import '../../shared/utils/image_helper.dart';
import '../../shared/utils/snackbar_helper.dart';
import '../../state/state.dart';

class FollowingSellersPage extends StatefulWidget {
  const FollowingSellersPage({super.key});

  @override
  State<FollowingSellersPage> createState() => _FollowingSellersPageState();
}

class _FollowingSellersPageState extends State<FollowingSellersPage> {
  final SellerFollowService _sellerFollowService = SellerFollowService();
  late Future<List<FollowingSellerItemModel>> _followingFuture;
  final Set<String> _pendingSellerIds = <String>{};

  @override
  void initState() {
    super.initState();
    _followingFuture = _loadFollowing();
  }

  Future<List<FollowingSellerItemModel>> _loadFollowing() async {
    final userId = context.read<UserState>().currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('Please log in to view followed sellers.');
    }
    return _sellerFollowService.fetchFollowingSellers(userId: userId);
  }

  void _refreshFollowing() {
    setState(() {
      _followingFuture = _loadFollowing();
    });
  }

  Future<void> _toggleFollow(UserModel seller) async {
    if (_pendingSellerIds.contains(seller.id)) {
      return;
    }

    setState(() {
      _pendingSellerIds.add(seller.id);
    });

    try {
      final message = await context.read<SellerFollowState>().toggleFollow(
        seller.id,
      );
      if (!mounted) {
        return;
      }
      SnackbarHelper.showTopMessage(context, message);
      _refreshFollowing();
    } catch (e) {
      if (!mounted) {
        return;
      }
      SnackbarHelper.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingSellerIds.remove(seller.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Following Sellers'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<List<FollowingSellerItemModel>>(
        future: _followingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_search_rounded, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load followed sellers',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _refreshFollowing,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final followedSellers = snapshot.data ?? const [];
          if (followedSellers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 80,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No followed sellers yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Follow sellers you like so you can find them quickly later.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Browse Marketplace'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshFollowing(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: followedSellers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = followedSellers[index];
                final seller = item.seller;
                final isPending = _pendingSellerIds.contains(seller.id);

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push('/seller/${seller.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ImageHelper.avatar(
                          seller.avatarUrl,
                          name: seller.name,
                          radius: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                seller.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                seller.bio?.isNotEmpty == true
                                    ? seller.bio!
                                    : 'Campus seller',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: isPending ? null : () => _toggleFollow(seller),
                          child: isPending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Unfollow'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
