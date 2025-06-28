# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Keep Kakao SDK classes
-keep class com.kakao.sdk.** { *; }
-keep class com.kakao.auth.** { *; }
-dontwarn com.kakao.**

# Additional Kakao SDK rules for Play Store
-keep class com.kakao.sdk.auth.AuthCodeHandlerActivity { *; }
-keep class com.kakao.sdk.flutter.AuthCodeCustomTabsActivity { *; }
-keepclassmembers class com.kakao.sdk.auth.** { *; }
-keepclassmembers class com.kakao.sdk.flutter.** { *; }

# Keep all Kakao SDK resources
-keepclasseswithmembernames class * {
    @com.kakao.sdk.* <methods>;
}

# Prevent obfuscation of Kakao SDK interfaces
-keep interface com.kakao.** { *; }