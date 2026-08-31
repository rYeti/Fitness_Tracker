allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. webcrypto 0.5.8) ship an android/build.gradle pinned to an
// old compileSdk that AndroidX libraries newer than it now refuse to compile
// against ("requires ... to compile against version 34 or later" from
// checkReleaseAarMetadata). The app itself already compiles against a current
// SDK; forcing every plugin subproject to match it fixes the metadata check
// without waiting on each plugin to bump its own pin.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.compileSdkVersion(36)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
