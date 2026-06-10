# Flutter / Dart embedding — Flutter Gradle Plugin이 자동 첨가하지만 명시.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-dontwarn io.flutter.embedding.**

# AndroidX & Material — Flutter가 호스트 native에서 reflective 접근.
-keep class androidx.lifecycle.DefaultLifecycleObserver { *; }
-dontwarn androidx.**

# Kotlin metadata — Kotlin reflection / coroutines가 일부 필요.
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations,RuntimeVisibleTypeAnnotations
-keepattributes Signature
-keepattributes InnerClasses
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# dio (HTTP) / cookie_jar / path_provider 등 plugin은 모두 Flutter MethodChannel
# 경유 — Dart 측만 사용하므로 추가 keep 불필요. 그러나 platform channel reflection
# 안정성을 위해 plugin 패키지 wildcard.
-keep class ** implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class ** implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# qr_flutter / flutter_secure_storage / google_fonts — 모두 Dart-side로
# 추가 rule 필요 없음 (다 standard Flutter plugin).

# ─────────────────────────────────────────────────────────────────────────
# flutter_local_notifications (Gson 2.8.9 번들) — R8 full-mode TypeToken 보존.
#
# 이 플러그인은 예약 알림을 Gson으로 (역)직렬화한다. AGP 8+의 R8 full-mode는
# 익명 `new TypeToken<...>(){}` 서브클래스의 **제네릭 시그니처를 제거**해, 런타임에
#   IllegalStateException: TypeToken must be created with a type argument …
#                          make sure that generic signatures are preserved
# 를 던진다. cancel()/cancelAll()/zonedSchedule() 등 거의 모든 알림 API가 내부적으로
# loadScheduledNotifications()를 호출하므로 **콜드부트마다** throw → 비정상 종료가
# 아닌데도 PlatformDispatcher.onError로 올라와 크래시 덤프에 기록되고, 다음 실행마다
# "오류가 발생했어요" 프롬프트가 뜨던 근본 원인(release 전용 — R8은 release에서만 동작).
#
# 플러그인은 consumerProguardFiles를 싣지 않아(android/build.gradle에 gson 2.8.9만
# implementation) **앱이 직접** 아래 규칙을 넣어야 한다. 출처: flutter_local_notifications
# 17.2.x example/android/app/proguard-rules.pro + Gson 공식 R8 가이드.
#
# 핵심은 마지막 두 줄(TypeToken 서브클래스 시그니처 보존) — R8 3.0+에서 필수.
# `Signature`만으로는 부족하고 `EnclosingMethod`(익명 클래스의 제네릭 상위 해석)도 필요.
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
# 플러그인 모델(ScheduledNotification 등)은 Gson 리플렉션 대상 → keep.
-keep class com.dexterous.** { *; }

# ─────────────────────────────────────────────────────────────────────────
# flutter_secure_storage(encryptedSharedPreferences) → androidx.security →
# Google Tink keyset. R8 full-mode가 Tink의 KeyManager 레지스트리/keyset 리더를
# 동적 참조라 인식 못 해 제거한다(실측: build/app/outputs/mapping/release/usage.txt에
# com.google.crypto.tink.KeysetHandle 계열이 REMOVED로 찍힘). 그러면 release에서
# EncryptedSharedPreferences.create()가 던지고, 플러그인은 이를 삼켜
# failedToUseEncryptedSharedPreferences=true로 **다른 백엔드에 폴백** → 기존에
# 저장한 토큰/UCheck 자격증명을 못 읽는다(로그인 경로 침묵 파손, release 전용).
# Tink가 싣는 consumer rule은 protobuf 필드뿐이고 플러그인은 consumer rule이 없어
# 앱이 직접 keep 해야 한다.
-keep class com.google.crypto.tink.** { *; }
-keep class * extends com.google.crypto.tink.shaded.protobuf.GeneratedMessageLite { <fields>; }
-keep class androidx.security.crypto.** { *; }
-dontwarn com.google.crypto.tink.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**

# SecureScreen MethodChannel (student_id) — 우리가 직접 만든 platform channel.
# package 전체 keep으로 안전.
-keep class sejong.sejong_univ_station.** { *; }

# 흔한 reflection-heavy 라이브러리에 대비.
-keep class **.R$* { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
