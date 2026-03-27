import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import 'settings_screen.dart';

/// Import mode for bulk word import
enum BulkImportMode { standard, synonymPair, antonymPair }

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _singleController = TextEditingController();
  final _bulkController = TextEditingController();
  BulkImportMode _importMode = BulkImportMode.standard;

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
          // Import mode selector
          const Text(
            'Chế độ nhập:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<BulkImportMode>(
            segments: const [
              ButtonSegment(
                value: BulkImportMode.standard,
                label: Text('Chuẩn'),
                icon: Icon(Icons.text_fields),
              ),
              ButtonSegment(
                value: BulkImportMode.synonymPair,
                label: Text('Đồng nghĩa'),
                icon: Icon(Icons.compare_arrows),
              ),
              ButtonSegment(
                value: BulkImportMode.antonymPair,
                label: Text('Trái nghĩa'),
                icon: Icon(Icons.swap_horiz),
              ),
            ],
            selected: {_importMode},
            onSelectionChanged: (Set<BulkImportMode> newSelection) {
              setState(() {
                _importMode = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Format instructions based on mode
          _buildFormatInstructions(),
          const SizedBox(height: 12),
          
          TextField(
            controller: _bulkController,
            minLines: 8,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: _getHintText(),
              border: const OutlineInputBorder(),
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

  Widget _buildFormatInstructions() {
    switch (_importMode) {
      case BulkImportMode.standard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Dán danh sách từ theo định dạng sau:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Từ\nLoại từ (n./v./adj./adv.)\n/Phát âm/ Nghĩa tiếng Việt',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ],
        );
      case BulkImportMode.synonymPair:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Dán cặp từ đồng nghĩa theo định dạng:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Word1 (nghĩa1) -> Word2 (nghĩa2)',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
            SizedBox(height: 4),
            Text(
              'VD: Empty (trống) -> Bare (trống trơn)',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        );
      case BulkImportMode.antonymPair:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Dán cặp từ trái nghĩa theo định dạng:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Word1 (nghĩa1) -> Word2 (nghĩa2)',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
            SizedBox(height: 4),
            Text(
              'VD: Empty (trống) -> Full (đầy)',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        );
    }
  }

  String _getHintText() {
    switch (_importMode) {
      case BulkImportMode.standard:
        return 'Ví dụ:\n\ncontainer\nn.\n/kən\'teinə/ cái đựng, chứa\n\ncontemporary\nadj.\n/kən\'tempərəri/ đương thời';
      case BulkImportMode.synonymPair:
        return 'Ví dụ:\n\nEmpty (trống) -> Bare (trống trơn)\nBig (lớn) -> Huge (khổng lồ)\nHappy (vui) -> Joyful (hạnh phúc)';
      case BulkImportMode.antonymPair:
        return 'Ví dụ:\n\nEmpty (trống) -> Full (đầy)\nBig (lớn) -> Small (nhỏ)\nHappy (vui) -> Sad (buồn)';
    }
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

    switch (_importMode) {
      case BulkImportMode.standard:
        await provider.addWordsBulk(_bulkController.text.trim());
        break;
      case BulkImportMode.synonymPair:
        await provider.addWordPairsBulk(
          _bulkController.text.trim(),
          isSynonym: true,
        );
        break;
      case BulkImportMode.antonymPair:
        await provider.addWordPairsBulk(
          _bulkController.text.trim(),
          isSynonym: false,
        );
        break;
    }

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
