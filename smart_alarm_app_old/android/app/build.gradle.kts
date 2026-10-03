subprojects {
    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            project.extensions.findByName("android")?.let { androidExt ->
                try {
                    val method = androidExt.javaClass.getMethod("setNdkVersion", String::class.java)
                    method.invoke(androidExt, "30.0.16248370")
                } catch (e: Exception) {
                    // 무시
                }
            }
        }
    }
}