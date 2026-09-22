# R8 / ProGuard rules for the release build.
#
# minifyEnabled and shrinkResources are BOTH on. That is what takes the arm64
# APK from ~20 MB to ~8 MB, and it is also the single most likely way to ship
# a build that passes every test on the desktop and then crashes in the
# basement, because R8 removes a class that is only ever reached by name.
#
# Every rule below exists for a reason. Do not "tidy" them without reading it.
#
# VERIFY ON THE DEVICE, not here: run a full session (rest timer with the
# screen off) and a full photo shoot on the signed release APK. A debug build
# is not minified and proves nothing about this file.

# ---------------------------------------------------------------- Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ---------------------------------------------------------------- Drift / sqlite3
#
# sqlite3_flutter_libs loads a NATIVE library; the Dart side never reflects
# over Java classes, so Drift itself needs nothing kept. These cover the JNI
# entry points and the optional pure-Java fallbacks so a stray reference does
# not turn into a build warning that hides a real one.
-keep class org.sqlite.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-dontwarn org.sqlite.**

# ---------------------------------------------------------------- Notifications
#
# The two receivers below are named as STRINGS in AndroidManifest.xml and in
# the plugin's own scheduling code. R8 cannot see those references, and if it
# strips or renames them the rest timer silently stops firing while the screen
# is off — which is exactly the failure that would not show up until you are
# mid-session with chalky hands.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# The plugin deserialises its scheduled-notification payloads with Gson, which
# IS reflective. Without these, a notification scheduled before a reboot comes
# back as garbage.
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn com.google.gson.**

# ---------------------------------------------------------------- Camera
#
# The progress-photo capture screen uses the `camera` plugin directly for its
# live preview, because the ghost overlay has to be drawn over the viewfinder.
# CameraX resolves implementations by name at runtime.
-keep class androidx.camera.** { *; }
-keep class io.flutter.plugins.camera.** { *; }
-dontwarn androidx.camera.**

# ---------------------------------------------------------------- Media
-keep class androidx.media3.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }
-dontwarn androidx.media3.**

# ---------------------------------------------------------------- Misc plugins
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class dev.fluttercommunity.plus.wakelock.** { *; }
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# ---------------------------------------------------------------- Play Core
#
# Flutter's engine references the deferred-components API even when no
# deferred components are used. Without this the release build fails with
# "Missing class com.google.android.play.core..." — a confusing error for a
# problem that does not exist in this app.
-dontwarn com.google.android.play.core.**

# ---------------------------------------------------------------- Keep names readable
#
# Line numbers in a crash report from a phone in a basement are worth more
# than the handful of kilobytes the mapping costs.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
