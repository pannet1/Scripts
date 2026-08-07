pluginManagement {
  repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolution {
  repositories { google(); mavenCentral() }
}
rootProject.name = "client"
include(":app")
