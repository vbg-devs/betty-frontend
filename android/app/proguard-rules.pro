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
