package com.example.english;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * Nhận broadcast khi người dùng dismiss notification và tự động re-show.
 * Đây là cơ chế chính để ngăn xóa notification trên Android 14+.
 * Hoạt động ngay cả khi app bị tắt hoàn toàn.
 */
public class NotificationDismissReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        int id       = intent.getIntExtra("id", 0);
        String title   = intent.getStringExtra("title");
        String body    = intent.getStringExtra("body");
        String payload = intent.getStringExtra("payload");

        // Re-show notification ngay lập tức khi bị dismiss
        if (title != null && body != null) {
            PersistentNotificationHelper.showNotification(context, id, title, body, payload);
        }
    }
}
