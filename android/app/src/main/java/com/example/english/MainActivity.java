package com.example.english;

import android.app.NotificationManager;
import android.content.Intent;
import android.os.Bundle;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "com.example.english/persistent_notification";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "scheduleAlarm": {
                        int id       = call.argument("id");
                        long timeMs  = ((Number) call.argument("timeMs")).longValue();
                        String title   = call.argument("title");
                        String body    = call.argument("body");
                        String payload = call.argument("payload");
                        PersistentNotificationHelper.scheduleAlarm(this, id, timeMs, title, body, payload);
                        result.success(null);
                        break;
                    }
                    case "cancelAlarm": {
                        int id = call.argument("id");
                        PersistentNotificationHelper.cancelAlarm(this, id);
                        result.success(null);
                        break;
                    }
                    case "cancelAll": {
                        PersistentNotificationHelper.cancelAll(this);
                        result.success(null);
                        break;
                    }
                    default:
                        result.notImplemented();
                }
            });
    }

    @Override
    protected void onResume() {
        super.onResume();
        cancelPersistentNotificationFromIntent(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        cancelPersistentNotificationFromIntent(intent);
    }

    /** Hủy persistent notification khi user mở app bằng cách tap vào notification đó. */
    private void cancelPersistentNotificationFromIntent(Intent intent) {
        if (intent == null) return;
        int notifId = intent.getIntExtra("persistent_notification_id", -1);
        if (notifId != -1) {
            NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            if (nm != null) nm.cancel(notifId);
        }
    }
}
