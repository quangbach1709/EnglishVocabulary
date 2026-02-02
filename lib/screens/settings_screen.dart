import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/tts_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();
  late Box _settingsBox;

  // TTS Settings
  double _speechRate = 0.5;
  String _selectedLanguage = 'en-US';

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _apiKeyController.text = _settingsBox.get('apiKey', defaultValue: '');
    _modelNameController.text = _settingsBox.get(
      'modelName',
      defaultValue: 'gemini-1.5-flash',
    );

    // Load TTS settings
    _speechRate = TtsService.instance.speechRate;
    _selectedLanguage = TtsService.instance.language;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelNameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    await _settingsBox.put('apiKey', _apiKeyController.text.trim());
    await _settingsBox.put('modelName', _modelNameController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved!')));
      Navigator.pop(context);
    }
  }

  void _testAudio() {
    TtsService.instance.speak('This is an example of the English voice.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // Audio Settings Section
            // ==========================================
            const Text(
              'Cài đặt âm thanh',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Speech Rate Slider
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tốc độ đọc: ${_speechRate.toStringAsFixed(1)}x'),
                      Slider(
                        value: _speechRate,
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        label: '${_speechRate.toStringAsFixed(1)}x',
                        onChanged: (value) async {
                          setState(() => _speechRate = value);
                          await TtsService.instance.setSpeechRate(value);
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.green),
                  tooltip: 'Test Audio',
                  onPressed: _testAudio,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Accent Dropdown
            Row(
              children: [
                const Icon(Icons.language, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Giọng đọc: '),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    isExpanded: true,
                    items: TtsService.availableAccents.map((accent) {
                      return DropdownMenuItem<String>(
                        value: accent['code'],
                        child: Text(accent['name']!),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        setState(() => _selectedLanguage = value);
                        await TtsService.instance.setLanguage(value);
                      }
                    },
                  ),
                ),
              ],
            ),

            const Divider(height: 32),

            // ==========================================
            // Gemini Configuration Section
            // ==========================================
            const Text(
              'Gemini Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                hintText: 'Enter your Gemini API Key',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modelNameController,
              decoration: const InputDecoration(
                labelText: 'Model Name',
                border: OutlineInputBorder(),
                hintText: 'e.g., gemini-1.5-flash',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Default: gemini-1.5-flash',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
