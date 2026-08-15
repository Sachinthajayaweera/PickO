allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
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
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    val configureAndroid = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val method = android::class.java.getMethod("setCompileSdk", java.lang.Integer::class.java)
                method.invoke(android, 36)
            } catch (e: Exception) {
                try {
                    val method = android::class.java.getMethod("compileSdkVersion", Int::class.java)
                    method.invoke(android, 36)
                } catch (e2: Exception) {
                    try {
                        val method = android::class.java.getMethod("compileSdkVersion", String::class.java)
                        method.invoke(android, "android-36")
                    } catch (e3: Exception) {
                        println("Could not override compileSdkVersion: ${e3.message}")
                    }
                }
            }
        }
    }
    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate {
            configureAndroid()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
