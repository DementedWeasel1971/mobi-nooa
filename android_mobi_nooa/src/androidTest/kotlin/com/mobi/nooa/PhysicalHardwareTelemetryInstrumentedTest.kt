package com.mobi.nooa

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * On-Device Physical Hardware & Telemetry Instrumented Test Suite.
 * Runs directly on attached physical Android devices to validate real hardware sensors,
 * RAM introspection, thermal governors, battery monitoring, and haptics.
 */
@RunWith(AndroidJUnit4::class)
class PhysicalHardwareTelemetryInstrumentedTest {

    private lateinit var context: Context
    private lateinit var bridge: DeviceHarnessBridge

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        bridge = DeviceHarnessBridge(context)
    }

    @Test
    fun testPhysicalBatteryTelemetry() {
        val batteryInfo = bridge.getBatteryInfo()
        assertNotNull("Battery info must not be null on physical hardware", batteryInfo)

        val batteryLevel = batteryInfo["batteryLevel"] as? Float
        assertNotNull("Battery level must be a Float", batteryLevel)
        assertTrue("Battery percentage must be between 0.0 and 1.0, was: $batteryLevel",
            batteryLevel!! in 0.0f..1.0f)

        val isCharging = batteryInfo["isCharging"] as? Boolean
        assertNotNull("isCharging flag must be a Boolean", isCharging)
    }

    @Test
    fun testPhysicalMemoryAndRamIntrospection() {
        val memInfo = bridge.getMemoryInfo()
        assertNotNull("Memory info must not be null on physical hardware", memInfo)

        val availMb = memInfo["availableRamMb"] as? Int
        val totalMb = memInfo["totalRamMb"] as? Int
        val isLowRam = memInfo["isLowRamDevice"] as? Boolean

        assertNotNull("Available RAM must be an Int", availMb)
        assertNotNull("Total RAM must be an Int", totalMb)
        assertNotNull("isLowRamDevice must be a Boolean", isLowRam)

        assertTrue("Physical device must have > 100MB available RAM, was: ${availMb}MB", availMb!! > 100)
        assertTrue("Physical device total RAM must be > 512MB, was: ${totalMb}MB", totalMb!! > 512)
        assertTrue("Total RAM must be greater than or equal to available RAM", totalMb >= availMb)
    }

    @Test
    fun testPhysicalThermalGovernorStatus() {
        val thermalStatus = bridge.getThermalStatus()
        assertNotNull("Thermal status must not be null", thermalStatus)

        val validStates = setOf("nominal", "fair", "serious", "severe", "critical", "emergency", "shutdown")
        assertTrue("Thermal status '$thermalStatus' must be one of valid states: $validStates",
            validStates.contains(thermalStatus))
    }

    @Test
    fun testPhysicalNetworkCapabilities() {
        val networkType = bridge.getNetworkStatus()
        assertNotNull("Network type must not be null", networkType)

        val validTypes = setOf("wifi", "cellular", "ethernet", "other", "none", "unknown")
        assertTrue("Network status '$networkType' must be one of valid types: $validTypes",
            validTypes.contains(networkType))
    }

    @Test
    fun testPhysicalFullDeviceStatusAggregation() {
        val fullStatus = bridge.getFullDeviceStatus()
        assertNotNull("Full status map must not be null", fullStatus)

        assertTrue("Must contain batteryLevel", fullStatus.containsKey("batteryLevel"))
        assertTrue("Must contain isCharging", fullStatus.containsKey("isCharging"))
        assertTrue("Must contain availableRamMb", fullStatus.containsKey("availableRamMb"))
        assertTrue("Must contain totalRamMb", fullStatus.containsKey("totalRamMb"))
        assertTrue("Must contain thermalState", fullStatus.containsKey("thermalState"))
        assertTrue("Must contain networkType", fullStatus.containsKey("networkType"))
        assertTrue("Must contain cpuLoadFraction", fullStatus.containsKey("cpuLoadFraction"))
    }

    @Test
    fun testPhysicalHapticFeedbackTrigger() {
        // Triggers safe 50ms vibration pulse on the physical device vibrator motor
        bridge.vibrate(50)
    }
}
