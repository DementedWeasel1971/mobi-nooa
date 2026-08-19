package com.mobi.nooa.app

import android.app.Activity
import android.os.Bundle

/**
 * Minimal launcher Activity for the `app` host module. This module exists
 * solely to satisfy the Flutter Gradle plugin's add-to-app requirement for
 * a `com.android.application` host project (see build.gradle.kts and
 * docs/decisions/0007-close-dart-android-bridge-gap.md) — it has no UI of
 * its own beyond this placeholder Activity.
 */
class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
}
