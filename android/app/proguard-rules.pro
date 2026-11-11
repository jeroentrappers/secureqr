# kotlinx.serialization, OkHttp, Coil, CameraX and ML Kit ship their own
# consumer rules. Keep the generated serializers of our API/history models.
-keepclassmembers class be.appmire.secureqr.data.** {
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
-keepattributes *Annotation*, InnerClasses
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
