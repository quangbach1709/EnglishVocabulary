import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../models/word.dart';
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WordProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
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
              Checkbox(
                value: provider.allSelected,
                onChanged: (_) => provider.toggleSelectAll(),
                fillColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
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
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          drawer: Drawer(
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
          ),
          body: provider.words.isEmpty
              ? const Center(child: Text('No words yet. Add some!'))
              : _buildGroupedList(context, provider),
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

  Widget _buildGroupedList(BuildContext context, WordProvider provider) {
    final groupedWords = provider.wordsByGroup;
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
            word.allMeaningsVi.isNotEmpty ? word.allMeaningsVi : word.meaningVi,
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
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Group Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.createGroup(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
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
        title: const Text('Delete Selected?'),
        content: Text(
          'Are you sure you want to delete ${provider.selectedWords.length} words?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteSelectedWords();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
