plugins {
    // ใช้ Google Services plugin ที่เวอร์ชันล่าสุด แต่ยังไม่ apply จนกว่าจะถึง module app
    id("com.google.gms.google-services") version "4.4.2" apply false
}

// ✅ ลบ allprojects{} ออก — ไม่ต้องมี repository ตรงนี้

// ตั้งค่าที่เก็บ build ออกไปนอก android/
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// ตั้งค่า build directory สำหรับทุก subproject
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

// คำสั่ง clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
