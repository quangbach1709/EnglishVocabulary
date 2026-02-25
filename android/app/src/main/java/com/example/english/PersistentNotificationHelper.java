package com.example.english;

import android.app.AlarmManager;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import androidx.core.app.NotificationCompat;

/**
 * Helper class tạo và lên lịch persistent notifications (không thể vuốt xóa).
 * Hoạt động trên Android 14+ bằng cách dùng setDeleteIntent để re-show khi bị dismiss.
 */
public class PersistentNotificationHelper {

    static final String CHANNEL_ID = "vocabulary_reminders";

    // Offset request codes để tránh xung đột với flutter_local_notifications
    private static final int ALARM_OFFSET = 50000;
    private static final int TAP_OFFSET   = 60000;
    private static final int DISMISS_OFFSET = 70000;

    /** Lên lịch alarm native để hiển thị persistent notification đúng giờ. */
    public static void scheduleAlarm(Context context, int id, long timeMs,
                                     String title, String body, String payload) {
        Intent intent = new Intent(context, PersistentAlarmReceiver.class);
        intent.putExtra("id", id);
        intent.putExtra("title", title);
        intent.putExtra("body", body);
        intent.putExtra("payload", payload);

        PendingIntent pendingIntent = PendingIntent.getBroadcast(
            context, ALARM_OFFSET + id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) return;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent);
        } else {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent);
        }
    }

    /** Hủy alarm và xóa notification (nếu đang hiển thị). */
    public static void cancelAlarm(Context context, int id) {
        Intent intent = new Intent(context, PersistentAlarmReceiver.class);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(
            context, ALARM_OFFSET + id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager != null) alarmManager.cancel(pendingIntent);

        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm != null) nm.cancel(id);
    }

    /** Hủy tất cả alarm trong dải ID được dùng bởi notification_service. */
    public static void cancelAll(Context context) {
        // Dải ID: today slots 1000–1004, next 7 days 10–74, custom 0–799, test 999
        for (int id = 0; id <= 1010; id++) {
            cancelAlarm(context, id);
        }
    }

    /**
     * Hiển thị persistent notification với setDeleteIntent.
     * Khi người dùng dismiss (dù bằng cách nào trên Android 14+),
     * NotificationDismissReceiver sẽ tự động re-show notification này.
     */
    public static void showNotification(Context context, int id,
                                        String title, String body, String payload) {
        // Intent mở app khi tap notification
        Intent tapIntent = new Intent(context, MainActivity.class);
        tapIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        tapIntent.putExtra("payload", payload);
        tapIntent.putExtra("persistent_notification_id", id);
        PendingIntent tapPendingIntent = PendingIntent.getActivity(
            context, TAP_OFFSET + id, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        // Intent re-show notification khi bị dismiss
        Intent dismissIntent = new Intent(context, NotificationDismissReceiver.class);
        dismissIntent.putExtra("id", id);
        dismissIntent.putExtra("title", title);
        dismissIntent.putExtra("body", body);
        dismissIntent.putExtra("payload", payload);
        PendingIntent dismissPendingIntent = PendingIntent.getBroadcast(
            context, DISMISS_OFFSET + id, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setContentIntent(tapPendingIntent)
            .setDeleteIntent(dismissPendingIntent); // <- key: re-show khi bị dismiss

        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm != null) nm.notify(id, builder.build());
    }
}
