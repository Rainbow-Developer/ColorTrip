import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun dartDefine(name: String): String? {
    val encodedDefines = project.findProperty("dart-defines") as String?
        ?: return null
    return encodedDefines
        .split(",")
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
        }
        .firstOrNull { it.startsWith("$name=") }
        ?.substringAfter("=")
        ?.takeIf { it.isNotBlank() }
}

val kakaoNativeAppKey = dartDefine("KAKAO_NATIVE_APP_KEY")
val buildsRelease = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (buildsRelease && kakaoNativeAppKey == null) {
    throw GradleException("KAKAO_NATIVE_APP_KEY is required for release builds.")
}

// 릴리스 서명 — android/key.properties 가 있으면 그 키로 서명하고, 없으면 debug 키로
// 폴백한다. 키스토어는 커밋하지 않으므로(루트 .gitignore) 대부분의 개발 머신에는 파일이
// 없는데, 그때도 `flutter build apk --release` 가 계속 되게 하려는 것이다.
// 폴백으로 만들어진 APK는 **스토어 업로드 불가**(내부 테스트 설치용).
// 설계·운영 절차: docs/specs/070-release-signing/
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

fun requiredKeystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("key.properties is missing '$name'.")

android {
    namespace = "com.rainbowdev.colortrip"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 스토어 식별자(KAN-109에서 io.vmonster → com.rainbowdev 로 변경). 바꾸면
        // 스토어에서는 다른 앱이 되고, Kakao Developers의 Android 플랫폼 패키지명도
        // 함께 갱신해야 한다(docs/conventions/auth-security.md).
        applicationId = "com.rainbowdev.colortrip"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["KAKAO_NATIVE_APP_KEY"] =
            kakaoNativeAppKey ?: ""
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(requiredKeystoreProperty("storeFile"))
                storePassword = requiredKeystoreProperty("storePassword")
                keyAlias = requiredKeystoreProperty("keyAlias")
                keyPassword = requiredKeystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // 스토어 업로드 불가. 내부 테스트 설치용으로만 쓴다.
                signingConfigs.getByName("debug")
            }
        }
    }
}

// 릴리스 빌드인데 키스토어가 없으면 조용히 debug 서명되는 것을 막기 위해 경고를 남긴다.
// 실패시키지 않는 이유: 키스토어 없는 개발 머신에서도 릴리스 빌드로 동작 확인을 해야 한다.
// logger.warn 은 flutter 가 Gradle 출력을 걸러내며 삼켜버려서(실측 확인) println 을 쓴다.
if (buildsRelease && !hasReleaseKeystore) {
    println(
        "경고: android/key.properties 가 없어 release APK를 debug 키로 서명합니다. " +
            "스토어 업로드는 불가하며 내부 테스트 설치용입니다. " +
            "설정 방법: android/key.properties.example 참고"
    )
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
