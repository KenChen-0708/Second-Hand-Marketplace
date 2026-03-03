import 'package:flutter/material.dart';

class SellPage extends StatefulWidget {
  const SellPage({super.key});

  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  String? _selectedCondition;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Textbooks', 'icon': Icons.menu_book_rounded},
    {'name': 'Electronics', 'icon': Icons.devices_rounded},
    {'name': 'Dorm Gear', 'icon': Icons.bed_rounded},
    {'name': 'Clothing', 'icon': Icons.checkroom_rounded},
    {'name': 'Sports', 'icon': Icons.sports_basketball_rounded},
    {'name': 'Beauty', 'icon': Icons.face_retouching_natural_rounded},
  ];

  final List<String> _conditions = [
    'New',
    'Like New',
    'Excellent',
    'Good',
    'Fair',
  ];

  void _onPublish() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Listing published successfully!'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(colorScheme, theme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionCard(
                      colorScheme,
                      icon: Icons.photo_library_rounded,
                      title: 'Photos',
                      subtitle: 'Add up to 5 clear photos of your item',
                      child: _buildImageSelector(colorScheme),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      colorScheme,
                      icon: Icons.info_outline_rounded,
                      title: 'Basic Information',
                      subtitle:
                          'Provide a catchy title and detailed description',
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _titleController,
                            label: 'Item Title',
                            hint: 'What are you selling?',
                            icon: Icons.title_rounded,
                            validator: (v) =>
                                v?.isEmpty ?? true ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _descController,
                            label: 'Description',
                            hint: 'Describe the features, usage, etc.',
                            icon: Icons.description_rounded,
                            maxLines: 4,
                            validator: (v) => v?.isEmpty ?? true
                                ? 'Description is required'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      colorScheme,
                      icon: Icons.category_rounded,
                      title: 'Classification',
                      subtitle: 'Help buyers find your item faster',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Category'),
                          const SizedBox(height: 12),
                          _buildCategorySelector(colorScheme),
                          const SizedBox(height: 24),
                          _buildLabel('Condition'),
                          const SizedBox(height: 12),
                          _buildConditionSelector(colorScheme),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      colorScheme,
                      icon: Icons.payments_rounded,
                      title: 'Pricing & Offer',
                      subtitle: 'Set your price and negotiation preference',
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _priceController,
                            label: 'Target Price',
                            hint: '0.00',
                            icon: Icons.attach_money_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: colorScheme.primary,
                                  child: const Icon(
                                    Icons.handshake_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Open to Offers',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        'Allow buyers to negotiate',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: true,
                                  onChanged: (v) {},
                                  activeColor: colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildPublishButton(colorScheme),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildAppBar(ColorScheme colorScheme, ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.primary,
      surfaceTintColor: colorScheme.primary,
      foregroundColor: Colors.white,

      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextButton.icon(
            onPressed: () {},
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(
              Icons.save_outlined,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Draft',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isCollapsed =
                constraints.maxHeight <=
                (MediaQuery.of(context).padding.top + kToolbarHeight + 20);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Listing',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: isCollapsed ? 20 : 26,
                    letterSpacing: -0.5,
                  ),
                ),
                if (!isCollapsed)
                  Text(
                    'Sell your item to the campus community',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            );
          },
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.8),
                    colorScheme.secondary.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
            // Decorative elements
            Positioned(
              top: -20,
              right: -20,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              bottom: 40,
              left: -10,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelector(ColorScheme colorScheme) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        children: [
          _buildAddImageButton(colorScheme),
          ...List.generate(3, (index) => _buildMockImageItem(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildAddImageButton(ColorScheme colorScheme) {
    return Container(
      width: 110,
      height: 110,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 2,
          style: BorderStyle.solid, // Could use dashed if package available
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_a_photo_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add Photo',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockImageItem(ColorScheme colorScheme) {
    return Container(
      width: 110,
      height: 110,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage('https://picsum.photos/300'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCategorySelector(ColorScheme colorScheme) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['name'];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: ChoiceChip(
              label: Text(cat['name']),
              avatar: Icon(
                cat['icon'],
                size: 16,
                color: isSelected ? Colors.white : colorScheme.primary,
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(
                  () => _selectedCategory = selected ? cat['name'] : null,
                );
              },
              showCheckmark: false,
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConditionSelector(ColorScheme colorScheme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _conditions.map((condition) {
        final isSelected = _selectedCondition == condition;
        return ChoiceChip(
          label: Text(condition),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedCondition = selected ? condition : null);
          },
          showCheckmark: false,
          selectedColor: colorScheme.primary,
          backgroundColor: colorScheme.surface,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPublishButton(ColorScheme colorScheme) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: _onPublish,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rocket_launch_rounded),
            SizedBox(width: 12),
            Text(
              'Publish Listing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
