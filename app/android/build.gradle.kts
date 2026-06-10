import org.jetbrains.kotlin.gradle.dsl.KotlinVersion
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// sentry_flutter 8.14.2의 android/build.gradle이 `kotlinOptions.languageVersion = "1.6"`
// 을 하드코딩 → 이 프로젝트의 Kotlin 2.2.20 컴파일러는 1.6/1.7/1.8 language version을
// 더는 지원하지 않아(1.9+만) "Language version 1.6 is no longer supported"로 빌드 실패.
// 전역 강제 대신 **해당 모듈에만** language/api version을 1.9로 끌어올린다(1.6용 코드는
// 1.9에서 그대로 컴파일됨). 플러그인이 1.9+로 핀을 올린 버전을 내면 이 블록은 제거 가능.
subprojects {
    afterEvaluate {
        if (project.name == "sentry_flutter") {
            tasks.withType<KotlinCompile>().configureEach {
                compilerOptions {
                    languageVersion.set(KotlinVersion.KOTLIN_1_9)
                    apiVersion.set(KotlinVersion.KOTLIN_1_9)
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
