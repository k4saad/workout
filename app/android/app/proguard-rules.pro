# Drift / sqlite3
-keep class org.sqlite.** { *; }
-keep class com.tekartik.sqflite.** { *; }
# Keep annotation info used by reflection-free codegen
-keepattributes *Annotation*, Signature, InnerClasses
