import 'dart:io';
import 'package:flutter/services.dart';

/// Platform channel để gọi native Android code tạo persistent notifications.
/// Chỉ hoạt động trên Android – iOS không cần vì iOS cho phép ongoing notifications.
class PersistentNotificationChannel {
  static const _channel = MethodChannel(
    'com.example.english/persistent_notification',
  );

  /// Lên lịch alarm native hiển thị persistent notification vào đúng thời điểm.
  /// [timeMs] là Unix timestamp (milliseconds) của thời điểm muốn hiển thị.
  static Future<void> scheduleAlarm({
    required int id,
    required int timeMs,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('scheduleAlarm', {
      'id': id,
      'timeMs': timeMs,
      'title': title,
      'body': body,
      'payload': payload,
    });
  }

  /// Hủy alarm và xóa notification đang hiển thị.
  static Future<void> cancelAlarm(int id) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('cancelAlarm', {'id': id});
  }

  /// Hủy tất cả persistent alarms/notifications.
  static Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('cancelAll');
  }
}
