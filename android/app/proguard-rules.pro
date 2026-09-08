# R8 keep rules for the release build.
#
# Only rules that protect a reference R8's static analysis genuinely
# cannot see belong here. Anything reachable from the manifest (our
# MainActivity, AdhanPlaybackService, AdhanAlarmReceiver,
# AzkarWidgetProvider, and the three com.dexterous receivers) is already
# kept automatically by AGP, which feeds the merged manifest to R8 as a
# keep source — so those are deliberately not repeated below.

# --- flutter_local_notifications -------------------------------------
# The one genuinely reflective path in this app. The plugin persists
# every *scheduled* notification (adhan, azkar, wird, weekly mission)
# across restarts and reboots by Gson-serializing
# ArrayList<NotificationDetails> to shared preferences, and rebuilds them
# through a RuntimeTypeAdapterFactory that resolves style subclasses by
# their *class name string*. So both field names and class simple-names
# have to survive intact: renaming either silently breaks deserialization
# on the next boot, which would look exactly like "no notifications all
# day" — the bug this app already spent a long time fixing for a
# different reason. Keeping names is cheap; being wrong here is not.
-keep class com.dexterous.** { *; }
-keepnames class com.dexterous.** { *; }

# --- Gson ------------------------------------------------------------
# Signature is what makes the TypeToken<ArrayList<NotificationDetails>>
# generic survive; without it Gson deserializes into LinkedTreeMap and
# the cast fails at runtime, not at build time.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn sun.misc.**

# --- Play Core -------------------------------------------------------
# Flutter's embedding references the deferred-components API even when
# the app doesn't use it, so R8 warns about classes that aren't bundled.
-dontwarn com.google.android.play.core.**
