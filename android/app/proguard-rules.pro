# kotlinx.serialization: keep generated serializers for @Serializable wire models.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class **$$serializer { *; }
-keepclasseswithmembers class social.betty.core.model.** {
    *** Companion;
}
-keep class social.betty.core.model.**$Companion { *; }

# OkHttp / Okio: platform-specific bits referenced reflectively.
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**

# androidx.security:security-crypto bundles Google Tink, which references compile-only
# annotations (errorprone / j2objc / javax) that aren't on the Android runtime classpath.
# R8 full-mode treats the resulting "missing class" references as errors without these.
-dontwarn com.google.errorprone.annotations.**
-dontwarn com.google.j2objc.annotations.**
-dontwarn javax.annotation.**
-dontwarn javax.annotation.concurrent.**
# Tink's KeysDownloader optionally uses the Google HTTP client + Joda-Time (not pulled in
# by security-crypto / EncryptedSharedPreferences) — suppress its unreachable references.
-dontwarn com.google.api.client.**
-dontwarn org.joda.time.**
-keep class com.google.crypto.tink.** { *; }
