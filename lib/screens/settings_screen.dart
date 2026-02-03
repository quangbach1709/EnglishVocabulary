import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/tts_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _firestoreService = FirestoreService();

  // State variables
  bool _isLoading = true;
  bool _obscureApiKey = true;
  double _speechRate = 0.5;
  String _selectedLanguage = 'en-US';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  /// Load settings from Firestore
  Future<void> _loadSettings() async {
    try {
      final settings = await _firestoreService.fetchUserSettings();
      setState(() {
        _apiKeyController.text = settings['apiKey'] ?? '';
        final model = settings['modelName'] as String?;
        _modelController.text = (model != null && model.isNotEmpty)
            ? model
            : 'gemini-1.5-flash';
        _speechRate = (settings['speechRate'] ?? 0.5).toDouble();
        _selectedLanguage = settings['ttsLanguage'] ?? 'en-US';
        _isLoading = false;
      });

      // Sync TTS service with cloud settings
      await TtsService.instance.setSpeechRate(_speechRate);
      await TtsService.instance.setLanguage(_selectedLanguage);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải cài đặt: $e')));
      }
    }
  }

  /// Save a single setting to Firestore
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      await _firestoreService.updateSetting(key, value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Test TTS with current settings
  void _testAudio() {
    TtsService.instance.speak('This is an example of the English voice.');
  }

  /// Test notification immediately
  Future<void> _testNotificationNow() async {
    final notificationService = NotificationService();
    await notificationService.showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi thông báo test! Kiểm tra thanh thông báo.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Test scheduled notification in 10 seconds
  Future<void> _testNotificationIn10Seconds() async {
    final notificationService = NotificationService();
    await notificationService.scheduleTestNotificationIn(10);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thông báo sẽ xuất hiện sau 10 giây!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  /// Reschedule all notifications
  Future<void> _rescheduleNotifications() async {
    final notificationService = NotificationService();
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await notificationService.initialize();
      final granted = await notificationService.requestPermissions();
      
      if (!granted) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng cấp quyền thông báo trong cài đặt!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      await notificationService.scheduleNext7Days();
      final pending = await notificationService.getPendingNotifications();
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lên lịch ${pending.length} thông báo cho 7 ngày tới!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show notification debug info
  Future<void> _showNotificationDebugInfo() async {
    final notificationService = NotificationService();
    final debugInfo = await notificationService.getDebugInfo();
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Debug Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Quyền thông báo:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${debugInfo['permissionsGranted']}'),
                const SizedBox(height: 12),
                Text(
                  'Số thông báo đang chờ: ${debugInfo['pendingCount']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if ((debugInfo['pendingNotifications'] as List).isNotEmpty) ...[
                  const Text('Các thông báo sắp tới:'),
                  ...(debugInfo['pendingNotifications'] as List).map((n) => 
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        '• ID ${n['id']}: ${n['title']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ] else
                  const Text(
                    'Không có thông báo nào được lên lịch!',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  /// Handle logout
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==========================================
                  // Section A: AI Configuration
                  // ==========================================
                  _buildSectionHeader('Cấu hình AI', Icons.psychology),
                  const SizedBox(height: 12),

                  // API Key with visibility toggle
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      border: const OutlineInputBorder(),
                      hintText: 'Nhập API Key của bạn',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscureApiKey = !_obscureApiKey);
                        },
                      ),
                    ),
                    onChanged: (value) {
                      // Debounce: save after user stops typing
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_apiKeyController.text == value) {
                          _saveSetting('apiKey', value.trim());
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Model Name TextField
                  TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model Name',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., gemini-1.5-flash',
                      prefixIcon: Icon(Icons.smart_toy),
                    ),
                    onChanged: (value) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_modelController.text == value) {
                          _saveSetting('modelName', value.trim());
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mặc định: gemini-1.5-flash',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),

                  const Divider(height: 32),

                  // ==========================================
                  // Section B: Audio & Voice (TTS)
                  // ==========================================
                  _buildSectionHeader('Cài đặt âm thanh', Icons.volume_up),
                  const SizedBox(height: 12),

                  // Speech Rate Slider
                  Row(
                    children: [
                      const Icon(Icons.speed, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tốc độ đọc: ${_speechRate.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Slider(
                              value: _speechRate,
                              min: 0.1,
                              max: 1.0,
                              divisions: 9,
                              label: '${_speechRate.toStringAsFixed(1)}x',
                              onChanged: (value) {
                                setState(() => _speechRate = value);
                                // Update TTS immediately for preview
                                TtsService.instance.setSpeechRate(value);
                              },
                              onChangeEnd: (value) async {
                                // Save to Firestore only when drag ends
                                await _saveSetting('speechRate', value);
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.play_circle,
                          color: Colors.green,
                          size: 32,
                        ),
                        tooltip: 'Thử giọng',
                        onPressed: _testAudio,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Language/Accent Dropdown
                  Row(
                    children: [
                      const Icon(Icons.language, color: Colors.orange),
                      const SizedBox(width: 12),
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
                              await _saveSetting('ttsLanguage', value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 32),

                  // ==========================================
                  // Section C: Notifications
                  // ==========================================
                  _buildSectionHeader('Thông báo ôn tập', Icons.notifications_active),
                  const SizedBox(height: 12),
                  
                  // Notification info card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Lịch thông báo hàng ngày',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• 8:00 - Buổi sáng\n'
                          '• 10:30 - Giữa sáng\n'
                          '• 12:30 - Buổi trưa\n'
                          '• 16:00 - Buổi chiều\n'
                          '• 20:00 - Buổi tối',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Test notification button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testNotificationNow,
                          icon: const Icon(Icons.notification_add),
                          label: const Text('Test ngay'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testNotificationIn10Seconds,
                          icon: const Icon(Icons.schedule),
                          label: const Text('Test sau 10s'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Reschedule notifications button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _rescheduleNotifications,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Đặt lại lịch thông báo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Debug info button
                  TextButton.icon(
                    onPressed: _showNotificationDebugInfo,
                    icon: const Icon(Icons.bug_report, size: 18),
                    label: const Text('Xem thông tin debug'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                  ),

                  const Divider(height: 32),

                  // ==========================================
                  // Section D: Account
                  // ==========================================
                  _buildSectionHeader('Tài khoản', Icons.person),
                  const SizedBox(height: 12),

                  // User Email (read-only)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            (user?.email?.isNotEmpty == true)
                                ? user!.email![0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'Người dùng',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                user?.email ?? 'Chưa đăng nhập',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Đăng xuất',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }
}
