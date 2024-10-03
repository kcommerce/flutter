package com.flutter.gradle

import com.android.build.api.dsl.ApplicationExtension
import org.gradle.api.Project
import org.jetbrains.annotations.VisibleForTesting

// TODO(gmackall): maybe migrate this to a package-level function when FGP conversion is done.
class BaseApplicationNameHandler {
    companion object {
        @VisibleForTesting
        const val DEFAULT_BASE_APPLICATION_NAME: String = "android.app.Application"

        @VisibleForTesting
        const val GRADLE_BASE_APPLICATION_NAME_PROPERTY: String = "base-application-name"

        @JvmStatic fun setBaseName(project: Project) {
            val androidComponentsExtension: ApplicationExtension = project.extensions.getByType(ApplicationExtension::class.java)
            androidComponentsExtension.defaultConfig.applicationId

            // Setting to android.app.Application is the same as omitting the attribute.
            var baseApplicationName: String = DEFAULT_BASE_APPLICATION_NAME

            // Respect this property if it set by the Flutter tool.
            if (project.hasProperty(GRADLE_BASE_APPLICATION_NAME_PROPERTY)) {
                baseApplicationName = project.property(GRADLE_BASE_APPLICATION_NAME_PROPERTY).toString()
            }

            androidComponentsExtension.defaultConfig.manifestPlaceholders["applicationName"] =
                baseApplicationName
        }
    }
}
