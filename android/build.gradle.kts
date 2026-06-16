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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val configureNamespace = {
        if (extensions.findByName("android") != null) {
            configure<com.android.build.gradle.BaseExtension> {
                if (namespace == null) {
                    val groupStr = project.group.toString()
                    namespace = if (groupStr.isEmpty() || groupStr == "unspecified") {
                        "com.example.${project.name.replace("[^a-zA-Z0-9_]".toRegex(), "")}"
                    } else {
                        groupStr
                    }
                }
            }
        }
    }

    if (state.executed) {
        configureNamespace()
    } else {
        afterEvaluate {
            configureNamespace()
        }
    }
}

