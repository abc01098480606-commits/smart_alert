allprojects {
    repositories {
        google()
        mavenCentral()
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// --- [무조건 NDK 버전을 빈 값으로 강제 고정하는 최후의 방어막] ---
subprojects {
    extensions.findByName("android")?.let { androidExt ->
        try {
            androidExt.javaClass.getMethod("setNdkVersion", String::class.java).invoke(androidExt, "")
        } catch (e: Exception) {
            // 무시
        }
    }
}