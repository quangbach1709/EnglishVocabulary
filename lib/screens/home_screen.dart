import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../models/word.dart';
import 'add_word_screen.dart';
import 'learning_screen.dart';
import 'edit_word_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'grammar_list_screen.dart';
import 'flashcard_screen.dart';

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

    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final groupName = sortedKeys[index];
        final words = groupedWords[groupName]!;
        final isCollapsed =
            groupName != null && provider.collapsedGroups.contains(groupName);

        // Check if all words in this group are selected
        final isGroupSelected = words.every(
          (w) => provider.selectedWords.contains(w),
        );

        Widget groupContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (groupName != null)
              InkWell(
                onTap: () => provider.toggleGroupExpansion(groupName),
                onLongPress: () =>
                    _showGroupOptions(context, provider, groupName),
                child: Container(
                  color: Colors.grey[200],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isGroupSelected,
                        onChanged: (_) =>
                            provider.toggleGroupSelection(groupName),
                      ),
                      Icon(isCollapsed ? Icons.expand_more : Icons.expand_less),
                      const SizedBox(width: 8),
                      Text(
                        groupName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text('${words.length} words'),
                    ],
                  ),
                ),
              ),
            if (!isCollapsed)
              ...words.map((word) => _buildWordTile(context, provider, word)),
          ],
        );

        if (groupName != null) {
          return Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: groupContent,
          );
        }

        return groupContent;
      },
    );
  }

  Widget _buildWordTile(
    BuildContext context,
    WordProvider provider,
    Word word,
  ) {
    final isSelected = provider.selectedWords.contains(word);

    return Dismissible(
      key: ObjectKey(word),
      direction: word.group != null
          ? DismissDirection.horizontal
          : DismissDirection.startToEnd,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.orange,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.folder_off, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Delete
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Word?'),
              content: Text('Are you sure you want to delete "${word.word}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    provider.deleteWord(word);
                    Navigator.of(context).pop(true);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        } else if (direction == DismissDirection.endToStart) {
          // Ungroup
          await provider.removeWordFromGroup(word);
          return false; // Don't dismiss the row, just update state
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
          subtitle: Text(word.meaningVi),
          selected: isSelected,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LearningScreen(word: word),
              ),
            );
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditWordScreen(word: word),
                    ),
                  );
                },
              ),
            ],
          ),
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
              title: const Text('Flashcard'),
              subtitle: const Text('SRS-based review with flip cards'),
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
  void _startFlashcardReview(BuildContext context, WordProvider provider) {
    final wordsForReview = provider.getWordsForReview();

    if (wordsForReview.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No words due for review! Great job! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reviewing ${wordsForReview.length} due words (Flashcard)',
        ),
        duration: const Duration(seconds: 2),
      ),
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
