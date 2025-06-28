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

# Keep ALL Kakao SDK classes and methods (CRITICAL for Play Store)
-keep class com.kakao.** { *; }
-keep class com.kakao.sdk.** { *; }
-keep class com.kakao.auth.** { *; }
-dontwarn com.kakao.**

# Force keep specific activity classes that were missing
-keep public class com.kakao.sdk.auth.AuthCodeHandlerActivity { 
    public *; 
    protected *; 
    private *; 
}
-keep public class com.kakao.sdk.flutter.AuthCodeCustomTabsActivity { 
    public *; 
    protected *; 
    private *; 
}
-keep public class com.kakao.sdk.flutter.AppsHandlerActivity { 
    public *; 
    protected *; 
    private *; 
}
-keep public class com.kakao.sdk.flutter.TalkAuthCodeActivity { 
    public *; 
    protected *; 
    private *; 
}

# Keep all methods and fields in Kakao SDK packages
-keepclassmembers class com.kakao.** { *; }
-keepnames class com.kakao.** { *; }
-keepclasseswithmembers class com.kakao.** { *; }

# Prevent any optimizations on Kakao SDK
-keep,allowobfuscation class com.kakao.**
-keep,allowshrinking class com.kakao.**

# Keep interfaces and annotations
-keep interface com.kakao.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod