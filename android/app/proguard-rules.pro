# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase + Ktor (HTTP client usado internamente)
-keep class io.supabase.** { *; }
-keep class io.ktor.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keep class kotlinx.serialization.** { *; }

# OkHttp / Retrofit (por si algún plugin los usa)
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class retrofit2.** { *; }

# Gson
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Evitar warnings
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-dontwarn io.ktor.**
-dontwarn kotlinx.**

# Necesario para reflection en modelos de datos
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}

# Google Play Core (requerido por Flutter embedding)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }