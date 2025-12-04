import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../models/word.dart';
import 'add_word_screen.dart';
import 'learning_screen.dart';
import 'review_screen.dart';
import 'edit_word_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WordProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            leading: Checkbox(
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
            title: Text(
              provider.selectedWords.isNotEmpty
                  ? '${provider.selectedWords.length} Selected'
                  : 'My Vocabulary',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.videogame_asset),
                tooltip: 'Play Game',
                onPressed:
                    (provider.selectedWords.isNotEmpty
                            ? provider.selectedWords.length
                            : provider.words.length) <
                        4
                    ? null
                    : () {
                        final wordsToPlay = provider.selectedWords.isNotEmpty
                            ? provider.selectedWords.toList()
                            : provider.words;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                GameScreen(words: wordsToPlay),
                          ),
                        );
                      },
              ),
              IconButton(
                icon: const Icon(Icons.school),
                tooltip: 'Review',
                onPressed: provider.words.isEmpty
                    ? null
                    : () {
                        final wordsToReview = provider.selectedWords.isNotEmpty
                            ? provider.selectedWords.toList()
                            : provider.words;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ReviewScreen(words: wordsToReview),
                          ),
                        );
                      },
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
                    provider.deleteWord(provider.words.indexOf(word));
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
            MaterialPageRoute(builder: (context) => LearningScreen(word: word)),
          );
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                // Find index for EditScreen (legacy requirement)
                final index = provider.words.indexOf(word);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditWordScreen(word: word, index: index),
                  ),
                );
              },
            ),
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
}
