import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/grammar_topic.dart';
import '../providers/grammar_provider.dart';
import 'grammar_practice_screen.dart';

class GrammarDetailScreen extends StatelessWidget {
  final GrammarTopic topic;

  const GrammarDetailScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(topic.topicEn)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startPractice(context),
        label: const Text('Practice'),
        icon: const Icon(Icons.quiz),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              topic.topicVi,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              topic.definition,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            // Formulas
            if (topic.formulas.isNotEmpty) ...[
              _buildSectionTitle(context, 'Formulas (Công thức)'),
              const SizedBox(height: 8),
              ...topic.formulas.map((formula) => _buildFormulaCard(formula)),
              const SizedBox(height: 16),
            ],

            // Usages
            if (topic.usages.isNotEmpty) ...[
              _buildSectionTitle(context, 'Usages (Cách dùng)'),
              const SizedBox(height: 8),
              ...topic.usages.map((usage) => _buildUsageItem(usage)),
              const SizedBox(height: 16),
            ],

            // Signs
            if (topic.signs.isNotEmpty) ...[
              _buildSectionTitle(context, 'Signs (Dấu hiệu nhận biết)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: topic.signs
                    .map(
                      (sign) => Chip(
                        label: Text(sign),
                        backgroundColor: Colors.blue.withOpacity(0.1),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Tips
            if (topic.tipsForBeginners.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  border: Border.all(color: Colors.amber),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lightbulb, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Tips for Beginners',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(topic.tipsForBeginners),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildFormulaCard(GrammarFormula formula) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formula.type,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const Divider(),
            Text(
              formula.structure,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ex: ${formula.example}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            if (formula.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                formula.explanation,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsageItem(GrammarUsage usage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87),
                children: [
                  TextSpan(
                    text: '${usage.context}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: usage.detail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPractice(BuildContext context) async {
    int quantity = 5;

    // Show Quantity Selection Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Start Practice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Number of questions: $quantity'),
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

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final provider = Provider.of<GrammarProvider>(context, listen: false);
      final exercises = await provider.generateExercises([topic], quantity);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating practice: $e')),
        );
      }
    }
  }
}
