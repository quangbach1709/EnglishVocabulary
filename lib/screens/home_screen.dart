import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../models/word.dart';
import '../services/study_service.dart';
import 'add_word_screen.dart';
import 'learning_screen.dart';
import 'word_detail_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'grammar_list_screen.dart';
import 'flashcard_screen.dart';

// Helper classes for flattened list approach
abstract class ListItem {}

class GroupHeaderItem implements ListItem {
  final String? groupName;
  final List<Word> words;
  final bool isExpanded;
  final bool isSelected;

  GroupHeaderItem({
    required this.groupName,
    required this.words,
    required this.isExpanded,
    required this.isSelected,
  });
}

class WordItem implements ListItem {
  final Word word;
  final bool isGrouped;
  final bool isLastInGroup;

  WordItem(this.word, {this.isGrouped = false, this.isLastInGroup = false});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StudyService _studyService = StudyService();
  bool _isSearching = false;
  bool _isGeneratingQueue = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startDailySession(BuildContext context) async {
    setState(() => _isGeneratingQueue = true);
    final provider = Provider.of<WordProvider>(context, listen: false);

    try {
      final dailyQueue = await _studyService.generateDailyQueue();

      if (!mounted) return;

      if (dailyQueue.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hôm nay không có từ nào cần học!'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // Update the dynamic daily group
        await provider.updateDailyStudyGroup(dailyQueue);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã cập nhật nhóm "Từ vựng hôm nay"!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingQueue = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: _isSearching
              ? _buildSearchAppBar(provider)
              : _buildNormalAppBar(context, provider),
          drawer: _buildDrawer(context),
          body: Column(
            children: [
              // Daily Study Card
              if (!provider.isLoading && provider.words.isNotEmpty)
                _buildDailyStudyCard(context, provider),

              // POS Filter chips
              if (provider.availablePosFilters.isNotEmpty)
                _buildPosFilterChips(provider),
              // Active filters indicator
              if (provider.hasActiveFilters) _buildActiveFiltersBar(provider),
              // Words list
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.words.isEmpty
                    ? const Center(child: Text('No words yet. Add some!'))
                    : _buildGroupedList(context, provider),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddWordScreen()),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildDailyStudyCard(BuildContext context, WordProvider provider) {
    final reviewCount = provider.reviewCount;
    final newCount = provider.newWordsCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.yellow, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Nhiệm vụ hôm nay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Bạn có $reviewCount từ cần ôn tập và $newCount từ mới.',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isGeneratingQueue
                        ? null
                        : () => _startDailySession(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isGeneratingQueue
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'LÊN DANH SÁCH HỌC HÔM NAY',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSearchAppBar(WordProvider provider) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
          provider.clearSearch();
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Tìm từ hoặc nghĩa...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: () {
                    _searchController.clear();
                    provider.clearSearch();
                  },
                )
              : null,
        ),
        style: const TextStyle(color: Colors.white, fontSize: 18),
        onChanged: (value) {
          provider.setSearchQuery(value);
          setState(() {}); // Update clear button visibility
        },
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(
    BuildContext context,
    WordProvider provider,
  ) {
    return AppBar(
      leading: Builder(
        builder: (context) {
          return IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        },
      ),
      title: Text(
        provider.selectedWords.isNotEmpty
            ? '${provider.selectedWords.length} Selected'
            : 'My Vocabulary',
      ),
      actions: [
        // Search button
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Tìm kiếm',
          onPressed: () {
            setState(() => _isSearching = true);
          },
        ),
        Checkbox(
          value: provider.allSelected,
          onChanged: (_) => provider.toggleSelectAll(),
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return null;
          }),
          checkColor: Colors.blue,
        ),
        IconButton(
          icon: const Icon(Icons.school),
          tooltip: 'Start Review',
          onPressed: provider.words.isEmpty
              ? null
              : () => _showReviewOptionsSheet(context, provider),
        ),
        if (provider.selectedWords.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Group Selected',
            onPressed: () => _showCreateGroupDialog(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Selected',
            onPressed: () => _confirmDeleteSelected(context, provider),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'English Learning',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
                SizedBox(height: 8),
                Text(
                  'Menu',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Vocabulary'),
            selected: true,
            onTap: () {
              Navigator.pop(context); // Close drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_books),
            title: const Text('Grammar'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GrammarListScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPosFilterChips(WordProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.filter_list, size: 20, color: Colors.grey),
            ),
            ...provider.availablePosFilters.map((pos) {
              final isSelected = provider.selectedPosFilters.contains(pos);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(
                    pos,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => provider.togglePosFilter(pos),
                  selectedColor: _getPosColor(pos),
                  backgroundColor: Colors.grey.shade200,
                  checkmarkColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getPosColor(String pos) {
    switch (pos.toLowerCase()) {
      case 'verb':
        return Colors.blue;
      case 'noun':
        return Colors.green;
      case 'adjective':
        return Colors.orange;
      case 'adverb':
        return Colors.purple;
      case 'preposition':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActiveFiltersBar(WordProvider provider) {
    final filteredCount = provider.filteredWords.length;
    final totalCount = provider.words.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hiển thị $filteredCount / $totalCount từ',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              provider.clearAllFilters();
              _searchController.clear();
              setState(() => _isSearching = false);
            },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Xóa bộ lọc'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context, WordProvider provider) {
    // Use filtered words instead of all words
    final groupedWords = provider.filteredWordsByGroup;
    final sortedKeys = groupedWords.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1; // Ungrouped at bottom
        if (b == null) return -1;
        return a.compareTo(b);
      });

    // Flatten the list: GroupHeaders + WordItems (if expanded)
    final List<ListItem> flatList = [];

    for (var groupName in sortedKeys) {
      final words = groupedWords[groupName]!;
      final isCollapsed =
          groupName != null && provider.collapsedGroups.contains(groupName);
      final isGroupSelected = words.every(
        (w) => provider.selectedWords.contains(w),
      );

      // Add Group Header (even for null group/ungrouped section if we want headers)
      // For ungrouped (null), we might still want a header or just separate them.
      // Current design treated 'null' group as just a header too.
      if (groupName != null) {
        flatList.add(
          GroupHeaderItem(
            groupName: groupName,
            words: words,
            isExpanded: !isCollapsed,
            isSelected: isGroupSelected,
          ),
        );
      }

      // Add Words if expanded (or ALWAYS for ungrouped if we treat it so)
      if (groupName == null || !isCollapsed) {
        for (int i = 0; i < words.length; i++) {
          flatList.add(
            WordItem(
              words[i],
              isGrouped: groupName != null,
              isLastInGroup: groupName != null && i == words.length - 1,
            ),
          );
        }
      }
    }

    return ListView.builder(
      itemCount: flatList.length,
      itemBuilder: (context, index) {
        final item = flatList[index];

        if (item is GroupHeaderItem) {
          return _buildGroupHeader(context, provider, item);
        } else if (item is WordItem) {
          return _buildWordTile(
            context,
            provider,
            item.word,
            isGrouped: item.isGrouped,
            isLastInGroup: item.isLastInGroup,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildGroupHeader(
    BuildContext context,
    WordProvider provider,
    GroupHeaderItem item,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0), // Top margin separate
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(12),
          bottom: item.isExpanded ? Radius.zero : const Radius.circular(12),
        ),
        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
      ),
      child: InkWell(
        onTap: () => provider.toggleGroupExpansion(item.groupName!),
        onLongPress: () =>
            _showGroupOptions(context, provider, item.groupName!),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(12),
          bottom: item.isExpanded ? Radius.zero : const Radius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Checkbox(
                value: item.isSelected,
                onChanged: (_) => provider.toggleGroupSelection(item.groupName),
              ),
              Icon(item.isExpanded ? Icons.expand_less : Icons.expand_more),
              const SizedBox(width: 8),
              Text(
                item.groupName!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text('${item.words.length} words'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordTile(
    BuildContext context,
    WordProvider provider,
    Word word, {
    bool isGrouped = false,
    bool isLastInGroup = false,
  }) {
    final isSelected = provider.selectedWords.contains(word);
    final hasGroup = word.group != null;

    Widget tileContent = Dismissible(
      key: ObjectKey(word),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: hasGroup ? Colors.orange : Colors.green,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          hasGroup ? Icons.folder_off : Icons.folder_open,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Delete word
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Xóa từ?'),
              content: Text('Bạn có chắc muốn xóa "${word.word}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () {
                    provider.deleteWord(word);
                    Navigator.of(context).pop(true);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Xóa'),
                ),
              ],
            ),
          );
        } else if (direction == DismissDirection.endToStart) {
          if (hasGroup) {
            // Has group - show confirmation to remove from group
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Xóa khỏi nhóm?'),
                content: Text(
                  'Bạn có chắc muốn xóa "${word.word}" khỏi nhóm "${word.group}"?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                    child: const Text('Xóa khỏi nhóm'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await provider.removeWordFromGroup(word);
            }
            return false; // Don't dismiss the row
          } else {
            // No group - show group picker
            await _showAddToGroupDialog(context, provider, word);
            return false; // Don't dismiss the row
          }
        }
        return false;
      },
      child: Container(
        color: WordProvider.getStatusColor(word.status),
        child: ListTile(
          leading: Checkbox(
            value: isSelected,
            onChanged: (_) => provider.toggleWordSelection(word),
          ),
          title: Text(word.word),
          subtitle: Text(
            word.allShortMeaningsVi.isNotEmpty
                ? word.allShortMeaningsVi
                : word.primaryShortMeaning,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          selected: isSelected,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WordDetailScreen(word: word),
              ),
            );
          },
          trailing: word.pos.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    word.pos.join(', '),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );

    if (isGrouped) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(color: Colors.blue.withOpacity(0.5), width: 1),
            right: BorderSide(color: Colors.blue.withOpacity(0.5), width: 1),
            bottom: isLastInGroup
                ? BorderSide(color: Colors.blue.withOpacity(0.5), width: 1)
                : BorderSide.none,
          ),
          borderRadius: isLastInGroup
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: tileContent,
      );
    }

    return tileContent;
  }

  /// Shows dialog to add an ungrouped word to an existing group
  Future<void> _showAddToGroupDialog(
    BuildContext context,
    WordProvider provider,
    Word word,
  ) async {
    final existingGroups = provider.existingGroups;

    if (existingGroups.isEmpty) {
      // No groups exist - show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có nhóm nào. Hãy tạo nhóm trước!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Thêm "${word.word}" vào nhóm',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: existingGroups.length,
                itemBuilder: (context, index) {
                  final groupName = existingGroups[index];
                  return ListTile(
                    leading: const Icon(Icons.folder, color: Colors.blue),
                    title: Text(groupName),
                    onTap: () async {
                      Navigator.pop(context);
                      await provider.addWordToGroup(word, groupName);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã thêm "${word.word}" vào "$groupName"',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WordProvider provider) {
    final existingGroups = provider.existingGroups;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _GroupSelectionSheet(
        existingGroups: existingGroups,
        selectedCount: provider.selectedWords.length,
        onSelectGroup: (groupName) async {
          Navigator.pop(context);
          await provider.moveSelectedWordsToGroup(groupName);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Đã di chuyển ${provider.selectedWords.length} từ vào "$groupName"',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onCreateGroup: (groupName) async {
          Navigator.pop(context);
          await provider.createGroup(groupName);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã tạo nhóm "$groupName"'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _showGroupOptions(
    BuildContext context,
    WordProvider provider,
    String groupName,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename Group'),
            onTap: () {
              Navigator.pop(context);
              _showRenameGroupDialog(context, provider, groupName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Group'),
            onTap: () {
              Navigator.pop(context);
              _confirmDeleteGroup(context, provider, groupName);
            },
          ),
        ],
      ),
    );
  }

  void _showRenameGroupDialog(
    BuildContext context,
    WordProvider provider,
    String oldName,
  ) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.renameGroup(oldName, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(
    BuildContext context,
    WordProvider provider,
    String groupName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group?'),
        content: Text(
          'Are you sure you want to delete "$groupName" and all its words?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteGroup(groupName);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected(BuildContext context, WordProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa các từ đã chọn?'),
        content: Text(
          'Bạn có chắc muốn xóa ${provider.selectedWords.length} từ đã chọn?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              await provider.deleteSelectedWords();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // Review Options Modal Bottom Sheet
  // ============================================

  void _showReviewOptionsSheet(BuildContext context, WordProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Review Mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Flashcard Mode - SRS based
            ListTile(
              leading: const Icon(Icons.flip, color: Colors.purple),
              title: const Text('Flashcard (Normal Review)'),
              subtitle: const Text('SRS-based review (Updates schedule)'),
              onTap: () {
                Navigator.pop(context);
                _startFlashcardReview(context, provider);
              },
            ),
            const Divider(),
            // Spelling Mode - Smart selection
            ListTile(
              leading: const Icon(Icons.keyboard, color: Colors.blue),
              title: const Text('Spelling (Điền từ)'),
              subtitle: const Text('Type the English word'),
              onTap: () {
                Navigator.pop(context);
                _startSpellingReview(context, provider);
              },
            ),
            const Divider(),
            // Multiple Choice Mode - Smart selection
            ListTile(
              leading: const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
              ),
              title: const Text('Multiple Choice (Chọn từ)'),
              subtitle: const Text('Choose the correct answer'),
              onTap: () {
                Navigator.pop(context);
                _startMultipleChoiceReview(context, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Flashcard Mode: Uses SRS-based words (nextReviewDate <= now)
  /// Flashcard Mode: Uses SRS-based words (nextReviewDate <= now)
  void _startFlashcardReview(BuildContext context, WordProvider provider) {
    List<Word> wordsForReview = [];
    String message = '';

    // 1. Case: Manual Selection
    if (provider.selectedWords.isNotEmpty) {
      final now = DateTime.now();
      // Filter: Due OR Forgot(0) OR Hard(1)
      wordsForReview = provider.selectedWords.where((w) {
        final isDue =
            w.nextReviewDate == null || w.nextReviewDate!.isBefore(now);
        final isDifficult = w.status == 0 || w.status == 1;
        return isDue || isDifficult;
      }).toList();

      if (wordsForReview.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selected words are not due for review yet! (Choose others or use Cram Mode)',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      message = 'Reviewing ${wordsForReview.length} selected due words';
    }
    // 2. Case: Global Review (No selection)
    else {
      wordsForReview = provider.getWordsForReview();
      if (wordsForReview.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No words due for review! Great job! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
      message = 'Reviewing ${wordsForReview.length} due words (Flashcard)';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlashcardScreen(words: wordsForReview),
      ),
    );
  }

  /// Spelling Mode: Uses selected words OR all words if none selected
  void _startSpellingReview(BuildContext context, WordProvider provider) {
    final List<Word> wordsToReview;
    final String message;

    // Smart Selection Logic
    if (provider.selectedWords.isNotEmpty) {
      wordsToReview = provider.selectedWords.toList();
      message = 'Reviewing ${wordsToReview.length} selected words (Spelling)';
    } else {
      wordsToReview = provider.words;
      message = 'Reviewing all ${wordsToReview.length} words (Spelling)';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningScreen(words: wordsToReview),
      ),
    );
  }

  /// Multiple Choice Mode: Uses selected words OR all words if none selected
  void _startMultipleChoiceReview(BuildContext context, WordProvider provider) {
    final List<Word> wordsToReview;
    final String message;

    // Smart Selection Logic
    if (provider.selectedWords.isNotEmpty) {
      wordsToReview = provider.selectedWords.toList();
      message =
          'Reviewing ${wordsToReview.length} selected words (Multiple Choice)';
    } else {
      wordsToReview = provider.words;
      message = 'Reviewing all ${wordsToReview.length} words (Multiple Choice)';
    }

    // Need at least 4 words for multiple choice
    if (wordsToReview.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 4 words for Multiple Choice mode!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameScreen(words: wordsToReview)),
    );
  }
}

// ============================================
// Group Selection Bottom Sheet Widget
// ============================================

class _GroupSelectionSheet extends StatefulWidget {
  final List<String> existingGroups;
  final int selectedCount;
  final Function(String) onSelectGroup;
  final Function(String) onCreateGroup;

  const _GroupSelectionSheet({
    required this.existingGroups,
    required this.selectedCount,
    required this.onSelectGroup,
    required this.onCreateGroup,
  });

  @override
  State<_GroupSelectionSheet> createState() => _GroupSelectionSheetState();
}

class _GroupSelectionSheetState extends State<_GroupSelectionSheet> {
  bool _isCreatingNew = false;
  final _newGroupController = TextEditingController();

  @override
  void dispose() {
    _newGroupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.folder, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Di chuyển ${widget.selectedCount} từ vào nhóm',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Create new group section
            if (_isCreatingNew) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newGroupController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Tên nhóm mới',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            widget.onCreateGroup(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _isCreatingNew = false;
                          _newGroupController.clear();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        if (_newGroupController.text.isNotEmpty) {
                          widget.onCreateGroup(_newGroupController.text);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Create new group button
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.green),
                title: const Text('Tạo nhóm mới'),
                onTap: () {
                  setState(() => _isCreatingNew = true);
                },
              ),
            ],

            if (widget.existingGroups.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'Hoặc chọn nhóm có sẵn:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Existing groups list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.existingGroups.length,
                  itemBuilder: (context, index) {
                    final groupName = widget.existingGroups[index];
                    return ListTile(
                      leading: const Icon(Icons.folder, color: Colors.blue),
                      title: Text(groupName),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () => widget.onSelectGroup(groupName),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
