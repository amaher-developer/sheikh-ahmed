import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play Store release signing — see android/key.properties (gitignored,
// never commit it) for the actual keystore path/passwords. Loaded here
// rather than hardcoded so the real credentials never appear in this
// file. Missing entirely (e.g. a fresh checkout without the keystore) is
// tolerated — the release build type below falls back to debug signing
// in that case, same as before, rather than failing the build outright.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sheikhahmed.sheikh_ahmed_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications requires this on Android.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must exactly match the package name the Play Console listing was
        // first created with (com.manassa.sheikhahmed) — that's fixed once
        // set and can't be changed without creating an entirely new app
        // listing. Deliberately left different from `namespace` above,
        // which stays as the actual Kotlin source package
        // (android/app/src/main/kotlin/com/sheikhahmed/sheikh_ahmed_app/)
        // — Android supports applicationId and namespace differing, and
        // this avoids renaming every Kotlin file and package declaration
        // just to match a store listing identifier.
        applicationId = "com.manassa.sheikhahmed"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real release signing when android/key.properties + the
            // keystore it points to are present (see above); falls back to
            // the debug key otherwise so `flutter run --release` still
            // works on a machine that doesn't have the release keystore —
            // that fallback is fine for local testing, but a build signed
            // that way will always be rejected by Play Console, which is
            // why this must resolve to "release" for an actual submission.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Flutter's default release build type shrinks unused Android
            // resources. res/raw/adhan_call.mp3 is only ever referenced
            // from Dart (as the string "adhan_call", passed to
            // RawResourceAndroidNotificationSound) rather than as
            // R.raw.adhan_call from native code, so the shrinker's static
            // reachability analysis can't see the reference. A
            // res/raw/keep.xml with a tools:keep directive fixed it for
            // the R8 shrink phase, but AGP's later AAPT2 "optimize" pass
            // silently dropped it anyway — confirmed by inspecting the
            // built APK directly, twice, with and without keep.xml.
            // Disabling shrinking outright removes that whole failure
            // mode; the app is small enough that the size cost is
            // negligible.
            isShrinkResources = false
            // Note that flag is the *resource* shrinker only. R8 code
            // shrinking below is now on; the reason it was once off: flutter_local_notifications
            // persists *scheduled* notifications (adhan, azkar/wird reminders)
            // across app restarts and device reboots by Gson-serializing its
            // internal model classes via reflection — a path R8's static
            // usage analysis can't see, so without exact-matching keep rules
            // it can silently strip/rename fields Gson needs, breaking
            // deserialization. That would explain exactly the symptom
            // reported: the *immediate* test notification (no serialization
            // involved) works, but every *scheduled* one silently doesn't.
            // The keep rules in proguard-rules.pro pin exactly that: every
            // com.dexterous class and field name survives R8 verbatim, so the
            // Gson round-trip still resolves. With those in place R8 is safe
            // to run, and it matters — the unshrunk build ships 15.6 MB of
            // DEX, most of it media3/AndroidX code that no path in this app
            // reaches, which is what Play Console flags as "App optimization:
            // Low".
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
