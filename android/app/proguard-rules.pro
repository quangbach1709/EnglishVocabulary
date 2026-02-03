# ==================================
# Flutter Local Notifications
# ==================================
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.isolate.** { *; }
-keep class com.dexterous.flutterlocalnotifications.utils.** { *; }

# Keep BroadcastReceivers
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver { *; }

# ==================================
# Gson (used by flutter_local_notifications)
# ==================================
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ==================================
# Firebase
# ==================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# ==================================
# Flutter
# ==================================
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ==================================
# Keep native methods
# ==================================
-keepclasseswithmembernames class * {
    native <methods>;
}

# ==================================
# Keep Parcelables
# ==================================
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# ==================================
# Keep Serializable classes
# ==================================
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# --- GIỮ LẠI CODE THÔNG BÁO (Đã có từ bước trước) ---
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# --- THÊM ĐOẠN NÀY ĐỂ SỬA LỖI R8 MỚI ---
# Bỏ qua các cảnh báo thiếu thư viện Google Play Core (Do Flutter Engine tham chiếu tới)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
