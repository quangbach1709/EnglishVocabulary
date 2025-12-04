import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();
  late Box _settingsBox;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _apiKeyController.text = _settingsBox.get('apiKey', defaultValue: '');
    _modelNameController.text = _settingsBox.get(
      'modelName',
      defaultValue: 'gemini-2.0-flash',
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                hintText: 'e.g., gemini-2.0-flash',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Default: gemini-2.0-flash',
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
