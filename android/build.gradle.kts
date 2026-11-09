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

// Force compileSdk 36 on all modules (must be registered BEFORE evaluationDependsOn)
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExtension = project.extensions.getByName("android")
            try {
                val method = androidExtension.javaClass.getMethod(
                    "setCompileSdkVersion", Int::class.javaPrimitiveType
                )
                method.invoke(androidExtension, 36)
            } catch (e: Exception) {
                try {
                    val method = androidExtension.javaClass.getMethod(
                        "setCompileSdk", Int::class.javaObjectType
                    )
                    method.invoke(androidExtension, 36)
                } catch (ignored: Exception) {
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}