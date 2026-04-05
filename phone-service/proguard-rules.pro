# PetalGemini ProGuard Rules

# Keep Room entities
-keep class com.petalgemini.db.** { *; }

# Keep Huawei Wear Engine
-keep class com.huawei.wearengine.** { *; }

# Keep Google AI SDK
-keep class com.google.ai.client.generativeai.** { *; }

# Keep JSON models
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
