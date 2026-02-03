import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  // Notification settings
  bool _notificationsEnabled = true;
  List<TimeOfDay> _notificationTimes = [
    const TimeOfDay(hour: 8, minute: 0),
    const TimeOfDay(hour: 12, minute: 30),
    const TimeOfDay(hour: 20, minute: 0),
  ];

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
        _notificationsEnabled = settings['notificationsEnabled'] ?? true;

        // Load notification times
        final savedTimes = settings['notificationTimes'] as List<dynamic>?;
        if (savedTimes != null && savedTimes.isNotEmpty) {
          _notificationTimes = savedTimes.map((t) {
            if (t is Map) {
              return TimeOfDay(hour: t['hour'] ?? 8, minute: t['minute'] ?? 0);
            }
            return const TimeOfDay(hour: 8, minute: 0);
          }).toList();
        }

        _isLoading = false;
      });

      // Sync TTS service with cloud settings
      await TtsService.instance.setSpeechRate(_speechRate);
      await TtsService.instance.setLanguage(_selectedLanguage);

      // Sync API settings from Firestore to Hive for GeminiService
      final settingsBox = Hive.box('settings');
      if (_apiKeyController.text.isNotEmpty) {
        await settingsBox.put('apiKey', _apiKeyController.text);
      }
      if (_modelController.text.isNotEmpty) {
        await settingsBox.put('modelName', _modelController.text);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải cài đặt: $e')));
      }
    }
  }

  /// Save a single setting to Firestore and sync to Hive for GeminiService
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      // Save to Firestore (cloud)
      await _firestoreService.updateSetting(key, value);

      // Also sync apiKey and modelName to Hive for GeminiService
      // GeminiService reads from Hive, not Firestore
      if (key == 'apiKey' || key == 'modelName') {
        final settingsBox = Hive.box('settings');
        await settingsBox.put(key, value);
      }
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

  /// Toggle notifications
  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);
    await _saveSetting('notificationsEnabled', enabled);

    final notificationService = NotificationService();
    if (enabled) {
      await _applyNotificationSchedule();
    } else {
      await notificationService.cancelAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tắt thông báo ôn tập'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Add a new notification time
  Future<void> _addNotificationTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      helpText: 'Chọn giờ thông báo',
    );

    if (picked != null) {
      // Check if time already exists
      final exists = _notificationTimes.any(
        (t) => t.hour == picked.hour && t.minute == picked.minute,
      );

      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Giờ này đã tồn tại!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() {
        _notificationTimes.add(picked);
        _notificationTimes.sort((a, b) {
          final aMinutes = a.hour * 60 + a.minute;
          final bMinutes = b.hour * 60 + b.minute;
          return aMinutes.compareTo(bMinutes);
        });
      });

      await _saveNotificationTimes();
    }
  }

  /// Remove a notification time
  Future<void> _removeNotificationTime(int index) async {
    if (_notificationTimes.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cần ít nhất 1 khung giờ thông báo!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _notificationTimes.removeAt(index);
    });

    await _saveNotificationTimes();
  }

  /// Edit a notification time
  Future<void> _editNotificationTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTimes[index],
      helpText: 'Chọn giờ thông báo',
    );

    if (picked != null) {
      setState(() {
        _notificationTimes[index] = picked;
        _notificationTimes.sort((a, b) {
          final aMinutes = a.hour * 60 + a.minute;
          final bMinutes = b.hour * 60 + b.minute;
          return aMinutes.compareTo(bMinutes);
        });
      });

      await _saveNotificationTimes();
    }
  }

  /// Save notification times to Firestore
  Future<void> _saveNotificationTimes() async {
    final timesData = _notificationTimes
        .map((t) => {'hour': t.hour, 'minute': t.minute})
        .toList();

    await _saveSetting('notificationTimes', timesData);
  }

  /// Apply notification schedule
  Future<void> _applyNotificationSchedule() async {
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
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng cấp quyền thông báo trong cài đặt!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Update notification service with custom times
      final schedules = _notificationTimes
          .map((t) => {'hour': t.hour, 'minute': t.minute})
          .toList();

      await notificationService.scheduleWithCustomTimes(schedules);
      final pending = await notificationService.getPendingNotifications();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lên lịch ${pending.length} thông báo!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
                  _buildSectionHeader(
                    'Thông báo ôn tập',
                    Icons.notifications_active,
                  ),
                  const SizedBox(height: 12),

                  // Enable/Disable notifications toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _notificationsEnabled
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _notificationsEnabled
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _notificationsEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                          color: _notificationsEnabled
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thông báo ôn tập',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                _notificationsEnabled ? 'Đang bật' : 'Đang tắt',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),

                  if (_notificationsEnabled) ...[
                    const SizedBox(height: 16),

                    // Custom notification times
                    Container(
                      padding: const EdgeInsets.all(16),
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
                              Icon(
                                Icons.schedule,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Khung giờ thông báo (${_notificationTimes.length} lần/ngày)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add_circle,
                                  color: Colors.blue.shade700,
                                ),
                                onPressed: _addNotificationTime,
                                tooltip: 'Thêm khung giờ',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // List of notification times
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_notificationTimes.length, (
                              index,
                            ) {
                              final time = _notificationTimes[index];
                              return GestureDetector(
                                onTap: () => _editNotificationTime(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.blue.shade300,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatTimeOfDay(time),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () =>
                                            _removeNotificationTime(index),
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.red.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 12),
                          Text(
                            'Nhấn vào giờ để chỉnh sửa, nhấn X để xóa',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Apply schedule button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _applyNotificationSchedule,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Áp dụng lịch thông báo'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

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
