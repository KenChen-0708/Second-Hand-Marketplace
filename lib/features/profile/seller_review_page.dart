import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../state/state.dart';
import '../../shared/utils/snackbar_helper.dart';

class SellerReviewPage extends StatefulWidget {
  final ProductModel? product;
  final String? orderId;

  const SellerReviewPage({super.key, this.product, this.orderId});

  @override
  State<SellerReviewPage> createState() => _SellerReviewPageState();
}

class _SellerReviewPageState extends State<SellerReviewPage> {
  int _rating = 0;
  final Set<String> _selectedTags = {};
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  UserModel? _seller;

  final List<String> _feedbackTags = [
    'Item as described',
    'Punctual',
    'Friendly',
    'Great price',
    'Smooth transaction',
    'Quick replies',
  ];

  @override
  void initState() {
    super.initState();
    _loadSellerInfo();
  }

  Future<void> _loadSellerInfo() async {
    if (widget.product == null) return;
    
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', widget.product!.sellerId)
          .single();
      
      if (mounted) {
        setState(() {
          _seller = UserModel.fromMap(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading seller info: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_rating == 0) return;
    if (widget.product == null) return;

    final userState = context.read<UserState>();
    final currentUser = userState.currentUser;
    
    if (currentUser == null) {
      SnackbarHelper.showError(context, 'You must be logged in to submit a review.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Create final comment combining tags and text
      String finalComment = _commentController.text.trim();
      if (_selectedTags.isNotEmpty) {
        final tagsString = _selectedTags.join(', ');
        finalComment = finalComment.isEmpty 
            ? 'Positive: $tagsString' 
            : '$finalComment\n\nHighlights: $tagsString';
      }

      final review = ReviewModel(
        id: const Uuid().v4(),
        orderId: widget.orderId ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}', // Fallback if no order passed
        reviewerId: currentUser.id,
        revieweeId: widget.product!.sellerId,
        productId: widget.product!.id,
        rating: _rating,
        comment: finalComment,
        createdAt: DateTime.now(),
      );

      await context.read<ReviewState>().submitReview(review);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to submit review: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.product == null) {
      return const Scaffold(body: Center(child: Text('Product information missing')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                children: [
                  const SizedBox(height: 16),
                  _buildTopSection(widget.product!, _seller),
                  const SizedBox(height: 40),

                  const Text(
                    'How was your experience?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildRatingStars(),
                  const SizedBox(height: 40),

                  const Text(
                    'What went well?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildFeedbackTags(),
                  const SizedBox(height: 32),

                  const Text(
                    'Leave a comment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildCommentBox(),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_rating > 0 && !_isSubmitting) ? _handleSubmit : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF10B981),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Submit Review',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(ProductModel product, UserModel? seller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              product.imageUrl ?? 'https://via.placeholder.com/150',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.image),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchased from',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(seller?.avatarUrl ?? 'https://i.pravatar.cc/150'),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        seller?.name ?? 'Loading...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  Widget _buildRatingStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _rating = index + 1;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 48,
              color: index < _rating ? Colors.amber : Colors.grey.shade300,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFeedbackTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _feedbackTags.map((tag) {
        final isSelected = _selectedTags.contains(tag);
        return FilterChip(
          label: Text(tag),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedTags.add(tag);
              } else {
                _selectedTags.remove(tag);
              }
            });
          },
          selectedColor: const Color(0xFF10B981).withOpacity(0.1),
          checkmarkColor: const Color(0xFF10B981),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF10B981)
                  : Colors.grey.shade300,
            ),
          ),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCommentBox() {
    return TextField(
      controller: _commentController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: 'Share more details about your experience...',
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
      ),
    );
  }
}
