import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/tts_service.dart';
import '../services/gemini_service.dart';

class WordDetailScreen extends StatefulWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  late Word _word;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _hasChanges = false;

  // Controllers for editing
  late TextEditingController _wordController;
  late TextEditingController _ipaController;
  late TextEditingController _meaningController;
  
  // Controllers for definitions
  List<_DefinitionControllers> _definitionControllers = [];

  @override
  void initState() {
    super.initState();
    _word = widget.word;
    _initControllers();
  }

  void _initControllers() {
    _wordController = TextEditingController(text: _word.word);
    _ipaController = TextEditingController(text: _word.primaryIpa.isNotEmpty ? _word.primaryIpa : _word.ipa);
    _meaningController = TextEditingController(text: _word.primaryMeaning.isNotEmpty ? _word.primaryMeaning : _word.meaningVi);
    
    _definitionControllers = _word.definitions.map((def) {
      return _DefinitionControllers(
        posController: TextEditingController(text: def.pos),
        textController: TextEditingController(text: def.text),
        translationController: TextEditingController(text: def.translation),
        exampleControllers: def.examples.map((ex) {
          return _ExampleControllers(
            textController: TextEditingController(text: ex.text),
            translationController: TextEditingController(text: ex.translation),
          );
        }).toList(),
      );
    }).toList();
    
    // If no definitions, use legacy format
    if (_definitionControllers.isEmpty && _word.meaningVi.isNotEmpty) {
      _definitionControllers.add(_DefinitionControllers(
        posController: TextEditingController(text: _word.pos.isNotEmpty ? _word.pos.first : ''),
        textController: TextEditingController(text: ''),
        translationController: TextEditingController(text: _word.meaningVi),
        exampleControllers: List.generate(
          _word.examplesEn.length,
          (i) => _ExampleControllers(
            textController: TextEditingController(text: _word.examplesEn[i]),
            translationController: TextEditingController(text: i < _word.examplesVi.length ? _word.examplesVi[i] : ''),
          ),
        ),
      ));
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _ipaController.dispose();
    _meaningController.dispose();
    for (var dc in _definitionControllers) {
      dc.dispose();
    }
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await TtsService.instance.speak(text);
  }

  Future<void> _addExamples(int definitionIndex) async {
    setState(() => _isLoading = true);
    try {
      final geminiService = GeminiService();
      final meaningContext = _definitionControllers[definitionIndex].translationController.text;
      final newExamples = await geminiService.fetchMoreExamples(_word.word, context: meaningContext);
      
      setState(() {
        for (var ex in newExamples) {
          _definitionControllers[definitionIndex].exampleControllers.add(
            _ExampleControllers(
              textController: TextEditingController(text: ex['text'] ?? ''),
              translationController: TextEditingController(text: ex['translation'] ?? ''),
            ),
          );
        }
        _hasChanges = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('Đã thêm ví dụ mới!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeExample(int defIndex, int exIndex) {
    setState(() {
      _definitionControllers[defIndex].exampleControllers[exIndex].dispose();
      _definitionControllers[defIndex].exampleControllers.removeAt(exIndex);
      _hasChanges = true;
    });
  }

  Word _buildUpdatedWord() {
    final definitions = _definitionControllers.asMap().entries.map((entry) {
      final dc = entry.value;
      return Definition(
        id: entry.key,
        pos: dc.posController.text,
        text: dc.textController.text,
        translation: dc.translationController.text,
        examples: dc.exampleControllers.asMap().entries.map((exEntry) {
          final ec = exEntry.value;
          return ExampleSentence(
            id: exEntry.key,
            text: ec.textController.text,
            translation: ec.translationController.text,
          );
        }).toList(),
      );
    }).toList();

    return _word.copyWith(
      word: _wordController.text,
      ipa: _ipaController.text,
      meaningVi: _meaningController.text,
      definitions: definitions,
    );
  }

  Future<void> _saveChanges() async {
    final provider = Provider.of<WordProvider>(context, listen: false);
    final updatedWord = _buildUpdatedWord();
    await provider.updateWord(updatedWord);
    
    setState(() {
      _word = updatedWord;
      _hasChanges = false;
      _isEditing = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thay đổi!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_word.word),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.green),
              tooltip: 'Lưu thay đổi',
              onPressed: _saveChanges,
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
            tooltip: _isEditing ? 'Xem' : 'Chỉnh sửa',
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Word Header Card
                  _buildWordHeaderCard(),
                  const SizedBox(height: 16),

                  // Parts of Speech
                  if (_word.pos.isNotEmpty) ...[
                    _buildPosSection(),
                    const SizedBox(height: 16),
                  ],

                  // Verb Forms
                  if (_word.verbs.isNotEmpty) ...[
                    _buildVerbFormsSection(),
                    const SizedBox(height: 16),
                  ],

                  // Pronunciations
                  if (_word.pronunciations.isNotEmpty) ...[
                    _buildPronunciationsSection(),
                    const SizedBox(height: 16),
                  ],

                  // Definitions
                  _buildDefinitionsSection(),

                  const SizedBox(height: 24),

                  // Status
                  _buildStatusSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildWordHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _isEditing
                      ? TextField(
                          controller: _wordController,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Từ vựng',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() => _hasChanges = true),
                        )
                      : Text(
                          _word.word,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 32, color: Colors.blue),
                  onPressed: () => _speak(_wordController.text),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // IPA
            _isEditing
                ? TextField(
                    controller: _ipaController,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: 'Phát âm (IPA)',
                      border: OutlineInputBorder(),
                      hintText: '/ˈeksəmpəl/',
                    ),
                    onChanged: (_) => setState(() => _hasChanges = true),
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _ipaController.text,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      if (_word.pos.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Wrap(
                          spacing: 6,
                          children: _word.pos.map((p) => _buildPosChip(p)).toList(),
                        ),
                      ],
                    ],
                  ),
            const SizedBox(height: 12),
            // Primary meaning
            _isEditing
                ? TextField(
                    controller: _meaningController,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: 'Nghĩa chính (Tiếng Việt)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    onChanged: (_) => setState(() => _hasChanges = true),
                  )
                : Text(
                    _meaningController.text,
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosChip(String pos) {
    MaterialColor color;
    switch (pos.toLowerCase()) {
      case 'verb':
        color = Colors.blue;
        break;
      case 'noun':
        color = Colors.green;
        break;
      case 'adjective':
      case 'adj':
        color = Colors.orange;
        break;
      case 'adverb':
      case 'adv':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Text(
        pos,
        style: TextStyle(
          fontSize: 12,
          color: color.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPosSection() {
    return _buildSection(
      title: 'Loại từ',
      icon: Icons.category,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _word.pos.map((p) => _buildPosChip(p)).toList(),
      ),
    );
  }

  Widget _buildVerbFormsSection() {
    return _buildSection(
      title: 'Các dạng từ',
      icon: Icons.transform,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _word.verbs.map((v) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  v.type,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  v.text,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPronunciationsSection() {
    return _buildSection(
      title: 'Phát âm',
      icon: Icons.record_voice_over,
      child: Column(
        children: _word.pronunciations.map((pron) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pron.lang == 'us' ? Colors.blue.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    pron.lang.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: pron.lang == 'us' ? Colors.blue.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  pron.pron,
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                if (pron.pos.isNotEmpty)
                  Text(
                    '(${pron.pos})',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                IconButton(
                  icon: const Icon(Icons.play_circle_outline, color: Colors.blue),
                  onPressed: () => _speak(_word.word),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDefinitionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Định nghĩa', Icons.menu_book),
        const SizedBox(height: 8),
        ...List.generate(_definitionControllers.length, (index) {
          final dc = _definitionControllers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Definition header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isEditing
                          ? SizedBox(
                              width: 100,
                              child: TextField(
                                controller: dc.posController,
                                decoration: const InputDecoration(
                                  hintText: 'noun/verb',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                style: const TextStyle(fontSize: 12),
                                onChanged: (_) => setState(() => _hasChanges = true),
                              ),
                            )
                          : _buildPosChip(dc.posController.text),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // English definition
                  _isEditing
                      ? TextField(
                          controller: dc.textController,
                          decoration: const InputDecoration(
                            labelText: 'Định nghĩa tiếng Anh',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          onChanged: (_) => setState(() => _hasChanges = true),
                        )
                      : dc.textController.text.isNotEmpty
                          ? Text(
                              dc.textController.text,
                              style: const TextStyle(
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                color: Colors.black87,
                              ),
                            )
                          : const SizedBox.shrink(),
                  if (dc.textController.text.isNotEmpty || _isEditing) const SizedBox(height: 8),

                  // Vietnamese translation
                  _isEditing
                      ? TextField(
                          controller: dc.translationController,
                          decoration: const InputDecoration(
                            labelText: 'Nghĩa tiếng Việt',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          onChanged: (_) => setState(() => _hasChanges = true),
                        )
                      : Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.translate, size: 18, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dc.translationController.text,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                  // Examples
                  if (dc.exampleControllers.isNotEmpty || _isEditing) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ví dụ:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Thêm ví dụ'),
                          onPressed: () => _addExamples(index),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(dc.exampleControllers.length, (exIndex) {
                      return _buildExampleItem(index, exIndex, dc.exampleControllers[exIndex]);
                    }),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExampleItem(int defIndex, int exIndex, _ExampleControllers ec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: _isEditing
                    ? TextField(
                        controller: ec.textController,
                        decoration: const InputDecoration(
                          hintText: 'Câu ví dụ tiếng Anh',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        maxLines: null,
                        onChanged: (_) => setState(() => _hasChanges = true),
                      )
                    : Text(ec.textController.text, style: const TextStyle(fontSize: 14)),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _speak(ec.textController.text),
              ),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeExample(defIndex, exIndex),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: _isEditing
                ? TextField(
                    controller: ec.translationController,
                    decoration: const InputDecoration(
                      hintText: 'Bản dịch tiếng Việt',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    onChanged: (_) => setState(() => _hasChanges = true),
                  )
                : Text(
                    ec.translationController.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    final statusColors = [
      Colors.red,
      Colors.orange,
      Colors.yellow.shade700,
      Colors.green,
    ];
    final statusLabels = ['Chưa thuộc', 'Khó', 'Đã thuộc', 'Thạo'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.assessment, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          const Text('Trạng thái:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColors[_word.status.clamp(0, 3)].withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColors[_word.status.clamp(0, 3)]),
            ),
            child: Text(
              statusLabels[_word.status.clamp(0, 3)],
              style: TextStyle(
                color: statusColors[_word.status.clamp(0, 3)],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          if (_word.group != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text(
                    _word.group!,
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title, icon),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }
}

// Helper classes for managing text controllers
class _DefinitionControllers {
  final TextEditingController posController;
  final TextEditingController textController;
  final TextEditingController translationController;
  final List<_ExampleControllers> exampleControllers;

  _DefinitionControllers({
    required this.posController,
    required this.textController,
    required this.translationController,
    required this.exampleControllers,
  });

  void dispose() {
    posController.dispose();
    textController.dispose();
    translationController.dispose();
    for (var ec in exampleControllers) {
      ec.dispose();
    }
  }
}

class _ExampleControllers {
  final TextEditingController textController;
  final TextEditingController translationController;

  _ExampleControllers({
    required this.textController,
    required this.translationController,
  });

  void dispose() {
    textController.dispose();
    translationController.dispose();
  }
}
