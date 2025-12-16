# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Keep notification-related classes
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }

# Keep alarm manager classes
-keep class android.app.AlarmManager { *; }
-keep class android.app.PendingIntent { *; }

# Gson (if used)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# Keep R classes
-keepclassmembers class **.R$* {
    public static <fields>;
}

