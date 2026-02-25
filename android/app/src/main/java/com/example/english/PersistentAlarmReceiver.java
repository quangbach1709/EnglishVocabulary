package com.example.english;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * Nhận alarm đã lên lịch và hiển thị persistent notification.
 * Hoạt động ngay cả khi app bị tắt hoàn toàn.
 */
public class PersistentAlarmReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        int id       = intent.getIntExtra("id", 0);
        String title   = intent.getStringExtra("title");
        String body    = intent.getStringExtra("body");
        String payload = intent.getStringExtra("payload");

        if (title != null && body != null) {
            PersistentNotificationHelper.showNotification(context, id, title, body, payload);
        }
    }
}
