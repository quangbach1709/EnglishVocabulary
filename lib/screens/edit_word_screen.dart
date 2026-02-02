import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/tts_service.dart';

class EditWordScreen extends StatefulWidget {
  final Word word;

  const EditWordScreen({super.key, required this.word});

  @override
  State<EditWordScreen> createState() => _EditWordScreenState();
}

class _EditWordScreenState extends State<EditWordScreen> {
  late TextEditingController _wordController;
  late TextEditingController _meaningController;
  late TextEditingController _ipaController;
  late List<TextEditingController> _exampleEnControllers;
  late List<TextEditingController> _exampleViControllers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.word.word);
    _meaningController = TextEditingController(text: widget.word.meaningVi);
    _ipaController = TextEditingController(text: widget.word.ipa);

    _exampleEnControllers = widget.word.examplesEn
        .map((e) => TextEditingController(text: e))
        .toList();
    _exampleViControllers = widget.word.examplesVi
        .map((e) => TextEditingController(text: e))
        .toList();
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    _ipaController.dispose();
    for (var c in _exampleEnControllers) c.dispose();
    for (var c in _exampleViControllers) c.dispose();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await TtsService.instance.speak(text);
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<WordProvider>(context, listen: false);
      final newWord = await provider.refreshWordData(_wordController.text);

      setState(() {
        _meaningController.text = newWord.meaningVi;
        _ipaController.text = newWord.ipa;

        // Clear old controllers
        for (var c in _exampleEnControllers) c.dispose();
        for (var c in _exampleViControllers) c.dispose();

        _exampleEnControllers = newWord.examplesEn
            .map((e) => TextEditingController(text: e))
            .toList();
        _exampleViControllers = newWord.examplesVi
            .map((e) => TextEditingController(text: e))
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data refreshed from Gemini!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addExamples() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<WordProvider>(context, listen: false);
      final currentWord = _buildCurrentWord();

      final updatedWord = await provider.addExamples(currentWord);

      setState(() {
        // Clear old controllers
        for (var c in _exampleEnControllers) c.dispose();
        for (var c in _exampleViControllers) c.dispose();

        _exampleEnControllers = updatedWord.examplesEn
            .map((e) => TextEditingController(text: e))
            .toList();
        _exampleViControllers = updatedWord.examplesVi
            .map((e) => TextEditingController(text: e))
            .toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Examples added!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Word _buildCurrentWord() {
    return widget.word.copyWith(
      word: _wordController.text,
      ipa: _ipaController.text,
      meaningVi: _meaningController.text,
      examplesEn: _exampleEnControllers.map((c) => c.text).toList(),
      examplesVi: _exampleViControllers.map((c) => c.text).toList(),
    );
  }

  void _save() {
    final provider = Provider.of<WordProvider>(context, listen: false);
    provider.updateWord(_buildCurrentWord());
    Navigator.pop(context);
  }

  void _removeExample(int index) {
    setState(() {
      _exampleEnControllers[index].dispose();
      _exampleViControllers[index].dispose();
      _exampleEnControllers.removeAt(index);
      _exampleViControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Word'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _wordController,
                          decoration: const InputDecoration(labelText: 'Word'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh Data from API',
                        onPressed: _refreshData,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ipaController,
                    decoration: InputDecoration(
                      labelText: 'IPA',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.volume_up, color: Colors.blue),
                        onPressed: () => _speak(_wordController.text),
                        tooltip: 'Listen',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _meaningController,
                    decoration: const InputDecoration(
                      labelText: 'Meaning (VN)',
                    ),
                    maxLines: null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Examples',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add More Examples'),
                        onPressed: _addExamples,
                      ),
                    ],
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _exampleEnControllers.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _exampleEnControllers[index],
                                      decoration: InputDecoration(
                                        labelText: 'Example ${index + 1} (EN)',
                                      ),
                                      maxLines: null,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => _removeExample(index),
                                  ),
                                ],
                              ),
                              TextField(
                                controller: _exampleViControllers[index],
                                decoration: InputDecoration(
                                  labelText: 'Example ${index + 1} (VN)',
                                ),
                                maxLines: null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
