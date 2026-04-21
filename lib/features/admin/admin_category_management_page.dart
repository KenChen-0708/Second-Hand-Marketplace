import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/category_state.dart';
import '../../models/models.dart';

class AdminCategoryManagementPage extends StatefulWidget {
  const AdminCategoryManagementPage({super.key});

  @override
  State<AdminCategoryManagementPage> createState() =>
      _AdminCategoryManagementPageState();
}

class _AdminCategoryManagementPageState
    extends State<AdminCategoryManagementPage> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryState>().fetchAllCategories();
    });
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSearchAndSortBar(),
              const SizedBox(height: 16),
              Expanded(
                child: Consumer<CategoryState>(
                  builder: (context, categoryState, child) {
                    if (categoryState.isLoading && categoryState.items.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (categoryState.hasError && categoryState.items.isEmpty) {
                      return _buildErrorState(categoryState.error);
                    }

                    final filteredItems = categoryState.filteredItems;

                    if (filteredItems.isEmpty) {
                      return const Center(child: Text('No categories found.'));
                    }

                    // Only enable reordering if in "Custom" sort mode and not searching
                    final bool canReorder = categoryState.sortMode == CategorySortMode.custom && 
                                          categoryState.searchQuery.isEmpty;

                    if (canReorder) {
                      return ReorderableListView.builder(
                        itemCount: filteredItems.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final items = List<CategoryModel>.from(filteredItems);
                          final item = items.removeAt(oldIndex);
                          items.insert(newIndex, item);
                          context.read<CategoryState>().updateCategoryOrder(items);
                        },
                        itemBuilder: (context, index) {
                          final category = filteredItems[index];
                          return _buildCategoryCard(category, key: ValueKey(category.id), canReorder: true);
                        },
                      );
                    } else {
                      return ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final category = filteredItems[index];
                          return _buildCategoryCard(category, key: ValueKey(category.id), canReorder: false);
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Category Manager',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            FilledButton.icon(
              onPressed: _showAddCategoryDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndSortBar() {
    return Consumer<CategoryState>(
      builder: (context, state, child) {
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) => state.setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: PopupMenuButton<CategorySortMode>(
                initialValue: state.sortMode,
                onSelected: (mode) => state.setSortMode(mode),
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sort Options',
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: CategorySortMode.custom,
                    child: Row(
                      children: [
                        Icon(Icons.drag_handle, size: 20),
                        SizedBox(width: 8),
                        Text('Custom (Manual)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: CategorySortMode.nameAsc,
                    child: Row(
                      children: [
                        Icon(Icons.sort_by_alpha, size: 20),
                        SizedBox(width: 8),
                        Text('Name (A-Z)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: CategorySortMode.nameDesc,
                    child: Row(
                      children: [
                        Icon(Icons.sort_by_alpha, size: 20),
                        SizedBox(width: 8),
                        Text('Name (Z-A)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: CategorySortMode.countDesc,
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, size: 20),
                        SizedBox(width: 8),
                        Text('Most Products'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: CategorySortMode.countAsc,
                    child: Row(
                      children: [
                        Icon(Icons.trending_down, size: 20),
                        SizedBox(width: 8),
                        Text('Least Products'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCard(CategoryModel category, {required Key key, required bool canReorder}) {
    final theme = Theme.of(context);
    final bool isEnabled = category.isEnabled;

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isEnabled ? Colors.black12 : Colors.red.withValues(alpha: 0.1)),
      ),
      color: isEnabled ? Colors.white : Colors.grey.shade50,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.only(left: 8, right: 12),
        leading: canReorder 
          ? ReorderableDragStartListener(
              index: context.read<CategoryState>().filteredItems.indexOf(category),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.drag_handle_rounded, color: Colors.black26),
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.category_outlined, color: Colors.black26),
            ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isEnabled ? Colors.black87 : Colors.black38,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildCountBadge(category.productCount),
          ],
        ),
        subtitle: Text(
          isEnabled ? 'Status: Active' : 'Status: Inactive',
          style: TextStyle(fontSize: 11, color: isEnabled ? Colors.green : Colors.red, fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: isEnabled,
              activeColor: theme.primaryColor,
              onChanged: (bool val) async {
                try {
                  await context.read<CategoryState>().toggleCategoryStatus(category.id, !val);
                } catch (e) {
                  _showErrorSnackBar(e.toString());
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _showEditCategoryDialog(category);
                if (val == 'delete') _confirmDeleteCategory(category);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
        onExpansionChanged: (expanded) {
          if (expanded) context.read<CategoryState>().fetchSubcategories(category.id);
        },
        children: [_buildSubcategorySection(category)],
      ),
    );
  }

  Widget _buildCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$count items', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
    );
  }

  Widget _buildSubcategorySection(CategoryModel category) {
    return Consumer<CategoryState>(
      builder: (context, state, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subcategories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  TextButton.icon(
                    onPressed: () => _showAddSubcategoryDialog(category.id),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.subcategories.isEmpty)
                const Text('No subcategories.', style: TextStyle(fontSize: 12, color: Colors.black38))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.subcategories.map((sub) {
                    return Chip(
                      label: Text(sub.name, style: const TextStyle(fontSize: 11)),
                      onDeleted: () => _confirmDeleteSubcategory(sub),
                      deleteIconColor: Colors.red.shade300,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.black12),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- Dialogs & Helpers ---

  Widget _buildErrorState(String? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text('Error: $error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showAddCategoryDialog() {
    _categoryController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (_categoryController.text.isNotEmpty) {
                Navigator.pop(context);
                await context.read<CategoryState>().addCategory(_categoryController.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddSubcategoryDialog(String categoryId) {
    _categoryController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Subcategory'),
        content: TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (_categoryController.text.isNotEmpty) {
                Navigator.pop(context);
                await context.read<CategoryState>().addSubcategory(categoryId, _categoryController.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(CategoryModel category) {
    _categoryController.text = category.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (_categoryController.text.isNotEmpty) {
                Navigator.pop(context);
                await context.read<CategoryState>().updateCategory(category.id, _categoryController.text.trim());
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Remove "${category.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await context.read<CategoryState>().deleteCategory(category.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubcategory(SubcategoryModel sub) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Subcategory?'),
        content: Text('Remove "${sub.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await context.read<CategoryState>().deleteSubcategory(sub.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
