import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WordProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add New Word')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter English Word',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (provider.isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: () async {
                  if (_controller.text.isNotEmpty) {
                    await provider.addWord(_controller.text);
                    if (provider.error == null && mounted) {
                      Navigator.pop(context);
                    } else if (provider.error != null && mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(provider.error!)));
                    }
                  }
                },
                child: const Text('Add Word'),
              ),
          ],
        ),
      ),
    );
  }
}
