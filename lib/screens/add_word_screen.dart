import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import 'settings_screen.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _singleController = TextEditingController();
  final _bulkController = TextEditingController();

  @override
  void dispose() {
    _singleController.dispose();
    _bulkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WordProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thêm từ mới'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add), text: 'Thêm một từ'),
              Tab(icon: Icon(Icons.library_add), text: 'Thêm hàng loạt'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSingleAdd(provider),
            _buildBulkAdd(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleAdd(WordProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _singleController,
            decoration: const InputDecoration(
              labelText: 'Nhập từ tiếng Anh',
              border: OutlineInputBorder(),
              hintText: 'VD: hello',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sử dụng Gemini AI để tự động lấy định nghĩa, phát âm và ví dụ.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          if (provider.isLoading)
            const CircularProgressIndicator()
          else
            ElevatedButton.icon(
              onPressed: () => _handleAddSingle(provider),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Thêm với AI'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBulkAdd(WordProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dán danh sách từ theo định dạng sau:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Từ\nLoại từ (n./v./adj./adv.)\n/Phát âm/ Nghĩa tiếng Việt',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bulkController,
            minLines: 8,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Ví dụ:\n\ncontainer\nn.\n/kən\'teinə/ cái đựng, chứa\n\ncontemporary\nadj.\n/kən\'tempərəri/ đương thời',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (provider.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton.icon(
              onPressed: () => _handleAddBulk(provider),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Thêm danh sách'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleAddSingle(WordProvider provider) async {
    if (_singleController.text.trim().isEmpty) return;

    await provider.addWord(_singleController.text.trim());
    if (mounted) {
      if (provider.error == null) {
        Navigator.pop(context);
      } else if (provider.error!.contains('API Key not found')) {
        _showApiKeyDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error!)),
        );
      }
    }
  }

  Future<void> _handleAddBulk(WordProvider provider) async {
    if (_bulkController.text.trim().isEmpty) return;

    await provider.addWordsBulk(_bulkController.text.trim());
    if (mounted) {
      if (provider.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm danh sách từ thành công!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thiếu API Key'),
        content: const Text(
          'Bạn cần cấu hình Gemini API Key để sử dụng tính năng thêm từ thông minh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            child: const Text('Cài đặt'),
          ),
        ],
      ),
    );
  }
}
