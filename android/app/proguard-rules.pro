-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.embedding.** { *; }

-keep class androidx.security.crypto.** { *; }
-keep class com.google.android.gms.auth.api.phone.** { *; }

-keep class com.google.zxing.** { *; }
-keep class com.budius.** { *; }

-keep class com.google.android.play.core.** { *; }

-keepattributes *Annotation*
-keepclassmembers class * implements java.io.Serializable