allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Use user.dir (the JVM working directory, without symlink resolution) to avoid
// Windows OneDrive junction points causing canonical-path mismatches.
// user.dir = Vertextapp/android; one parentFile up = Vertextapp; /build = Vertextapp/build.
val newBuildDirFile: File = File(System.getProperty("user.dir"))
    .parentFile   // Vertextapp/
    .resolve("build")
rootProject.layout.buildDirectory.set(newBuildDirFile)

subprojects {
    project.layout.buildDirectory.set(File(newBuildDirFile, project.name))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
