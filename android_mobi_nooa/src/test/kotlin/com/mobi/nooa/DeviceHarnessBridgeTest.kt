package com.mobi.nooa

import android.app.ActivityManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.PowerManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

class DeviceHarnessBridgeTest {

    private lateinit var context: Context
    private lateinit var activityManager: ActivityManager
    private lateinit var powerManager: PowerManager
    private lateinit var connectivityManager: ConnectivityManager
    private lateinit var bridge: DeviceHarnessBridge

    @Before
    fun setUp() {
        context = mock(Context::class.java)
        activityManager = mock(ActivityManager::class.java)
        powerManager = mock(PowerManager::class.java)
        connectivityManager = mock(ConnectivityManager::class.java)

        `when`(context.getSystemService(Context.ACTIVITY_SERVICE)).thenReturn(activityManager)
        `when`(context.getSystemService(Context.POWER_SERVICE)).thenReturn(powerManager)
        `when`(context.getSystemService(Context.CONNECTIVITY_SERVICE)).thenReturn(connectivityManager)

        bridge = DeviceHarnessBridge(context)
    }

    @Test
    fun testMemoryInfoRetrieval() {
        val memInfo = bridge.getMemoryInfo()
        assertNotNull(memInfo)
        assertTrue(memInfo.containsKey("availableRamMb"))
        assertTrue(memInfo.containsKey("totalRamMb"))
        assertTrue(memInfo.containsKey("isLowRamDevice"))
    }

    @Test
    fun testThermalStatusDefaultsToNominal() {
        val thermal = bridge.getThermalStatus()
        assertNotNull(thermal)
        assertEquals("nominal", thermal)
    }

    @Test
    fun testFullDeviceStatusAggregatesMetrics() {
        val status = bridge.getFullDeviceStatus()
        assertNotNull(status)
        assertTrue(status.containsKey("batteryLevel"))
        assertTrue(status.containsKey("availableRamMb"))
        assertTrue(status.containsKey("totalRamMb"))
        assertTrue(status.containsKey("thermalState"))
        assertTrue(status.containsKey("networkType"))
    }
}
