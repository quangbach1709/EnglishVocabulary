import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/grammar_provider.dart';
import '../models/grammar_topic.dart';
import 'grammar_detail_screen.dart';
import 'grammar_practice_screen.dart';

class GrammarListScreen extends StatefulWidget {
  const GrammarListScreen({super.key});

  @override
  State<GrammarListScreen> createState() => _GrammarListScreenState();
}

class _GrammarListScreenState extends State<GrammarListScreen> {
  final Set<String> _selectedTopicIds = {};

  void _toggleSelection(String topicId) {
    setState(() {
      if (_selectedTopicIds.contains(topicId)) {
        _selectedTopicIds.remove(topicId);
      } else {
        _selectedTopicIds.add(topicId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GrammarProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _selectedTopicIds.isNotEmpty
                  ? '${_selectedTopicIds.length} Selected'
                  : 'Grammar Lessons',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add New Topic',
                onPressed: () => _showAddTopicDialog(context, provider),
              ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.topics.isEmpty
              ? const Center(child: Text('No grammar topics yet. Add one!'))
              : ListView.builder(
                  itemCount: provider.topics.length,
                  itemBuilder: (context, index) {
                    final topic = provider.topics[index];
                    // Using topicEn as key for simplicity, assuming uniqueness or use Hive key if accessible
                    // HiveObject key is dynamic, so let's use topic object reference for selection?
                    // But we want ID. Let's use topic.key.toString() if verified.
                    // But for now, let's use the object reference logic by ID or just index?
                    // The safest is to use the topic object itself, but Set<GrammarTopic> requires equals/hashcode.
                    // Let's use topic.key (Hive key).
                    final topicKey = topic.key.toString();
                    final isSelected = _selectedTopicIds.contains(topicKey);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(topicKey),
                        ),
                        title: Text(
                          topic.topicEn,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(topic.topicVi),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () =>
                              _confirmDelete(context, provider, topic),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GrammarDetailScreen(topic: topic),
                            ),
                          );
                        },
                        onLongPress: () => _toggleSelection(topicKey),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _handlePractice(context, provider),
            label: Text(
              _selectedTopicIds.isEmpty
                  ? 'Practice All'
                  : 'Practice (${_selectedTopicIds.length})',
            ),
            icon: const Icon(Icons.school),
          ),
        );
      },
    );
  }

  Future<void> _handlePractice(
    BuildContext context,
    GrammarProvider provider,
  ) async {
    if (provider.topics.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No topics to practice!')));
      return;
    }

    List<GrammarTopic> topicsToPractice = [];

    if (_selectedTopicIds.isEmpty) {
      // Confirm practice ALL
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Practice All?'),
          content: Text(
            'Do you want to practice all ${provider.topics.length} topics?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      topicsToPractice = provider.topics;
    } else {
      topicsToPractice = provider.topics
          .where((t) => _selectedTopicIds.contains(t.key.toString()))
          .toList();
    }

    if (!context.mounted) return;
    _startPracticeSession(context, provider, topicsToPractice);
  }

  Future<void> _startPracticeSession(
    BuildContext context,
    GrammarProvider provider,
    List<GrammarTopic> topics,
  ) async {
    int quantity = 5;

    // Quantity Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Practice Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Questions per topic: $quantity'),
              Text(
                'Total questions: ${quantity * topics.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: quantity.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: quantity.toString(),
                onChanged: (value) {
                  setState(() => quantity = value.round());
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final exercises = await provider.generateExercises(topics, quantity);

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GrammarPracticeScreen(exercises: exercises),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddTopicDialog(BuildContext context, GrammarProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Grammar Topic'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g., Present Simple, Passive Voice',
            labelText: 'Topic Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final input = controller.text.trim();
              if (input.isNotEmpty) {
                Navigator.pop(context);
                try {
                  await provider.addTopic(input);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Topic added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    GrammarProvider provider,
    GrammarTopic topic,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Topic?'),
        content: Text('Are you sure you want to delete "${topic.topicEn}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteTopic(topic);
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
