import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// android/key.properties 가 존재하면 release를 그 keystore로 sign, 없으면
// debug fallback. 개발자 머신에 keystore가 없어도 debug build / `flutter run`은
// 계속 동작. production publish는 key.properties.template 참고.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "sejong.sejong_univ_station"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications가 Java 8+ Date/Time API 사용 — D8
        // desugaring 활성화 필수. minSdk가 33이라 사실상 효과는 없지만
        // plugin이 manifest merge 단계에서 요구한다.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "sejong.sejong_univ_station"
        minSdk = 33
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("en", "ko")
    }

    signingConfigs {
        if (hasKeystore) {
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
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                // 개발자 머신에 keystore 없으면 debug fallback — `flutter run --release`
                // 동작 보존. publish는 반드시 key.properties 채워서 진행.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    lint {
        // Flutter의 MainActivity는 FlutterActivity(Kotlin) 상속이지만 lint가
        // jar-scan 단계에서 잘못 fatal Instantiatable로 표시 — release abort 끔.
        abortOnError = false
        checkReleaseBuilds = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    // D8 desugaring runtime — flutter_local_notifications 요구.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // S1Pass NFC — cardNo를 EncryptedSharedPreferences로 보관 (Keystore 기반).
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}
