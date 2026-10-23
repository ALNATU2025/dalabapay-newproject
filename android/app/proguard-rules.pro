# Flutter specific
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Keep your app classes
-keep class com.dalabapay.official.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep your model classes if you have any
-keep class com.dalabapay.official.models.** { *; }
# Flutter's deferred-components code refers to Google Play Core, which this
# app doesn't include. Without these lines R8 stops the release build with
# "Missing class com.google.android.play.core...".
-dontwarn com.google.android.play.core.**

# Firebase Auth (SMS sign-up): optional classes it may refer to.
-dontwarn com.google.android.recaptcha.**
-dontwarn com.google.firebase.appcheck.**
-keep class com.google.firebase.** { *; }
