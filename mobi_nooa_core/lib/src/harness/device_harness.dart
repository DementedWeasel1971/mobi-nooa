import 'dart:async';

/// Mobile hardware thermal throttling states.
enum ThermalState {
  nominal,
  fair,
  serious,
  severe,
  critical,
  emergency,
  shutdown,
}

/// Device state snapshot (battery, network, sensors, memory, thermals).
class DeviceStatus {
  final double batteryLevel; // 0.0 to 1.0
  final bool isCharging;
  final String networkType; // 'wifi', 'cellular', 'none'
  final bool isLowPowerMode;
  final int freeDiskSpaceMb;
  final int totalDiskSpaceMb;
  final int availableRamMb;
  final int totalRamMb;
  final bool isLowRamDevice;
  final ThermalState thermalState;
  final double cpuLoadFraction; // 0.0 to 1.0

  const DeviceStatus({
    this.batteryLevel = 0.85,
    this.isCharging = false,
    this.networkType = 'wifi',
    this.isLowPowerMode = false,
    this.freeDiskSpaceMb = 12400,
    this.totalDiskSpaceMb = 128000,
    this.availableRamMb = 4096,
    this.totalRamMb = 8192,
    this.isLowRamDevice = false,
    this.thermalState = ThermalState.nominal,
    this.cpuLoadFraction = 0.15,
  });

  Map<String, dynamic> toJson() => {
        'batteryLevel': batteryLevel,
        'isCharging': isCharging,
        'networkType': networkType,
        'isLowPowerMode': isLowPowerMode,
        'freeDiskSpaceMb': freeDiskSpaceMb,
        'totalDiskSpaceMb': totalDiskSpaceMb,
        'availableRamMb': availableRamMb,
        'totalRamMb': totalRamMb,
        'isLowRamDevice': isLowRamDevice,
        'thermalState': thermalState.name,
        'cpuLoadFraction': cpuLoadFraction,
      };
}

/// Device Location coordinates.
class DeviceLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;

  DeviceLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters = 10.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Interface for mobile device capabilities.
abstract class DeviceHarness {
  Future<DeviceStatus> getStatus();
  Future<DeviceLocation> getLocation();
  Future<void> sendNotification({
    required String title,
    required String body,
    int? id,
  });
  Future<void> vibrate({int durationMs = 200});
}

/// Default in-memory / simulated mobile device harness.
class DefaultDeviceHarness implements DeviceHarness {
  DeviceStatus _status;
  DeviceLocation _location;
  final List<Map<String, dynamic>> sentNotifications = [];

  DefaultDeviceHarness({
    DeviceStatus? initialStatus,
    DeviceLocation? initialLocation,
  })  : _status = initialStatus ?? const DeviceStatus(),
        _location = initialLocation ??
            DeviceLocation(latitude: 37.7749, longitude: -122.4194);

  void updateStatus(DeviceStatus status) => _status = status;
  void updateLocation(DeviceLocation loc) => _location = loc;

  @override
  Future<DeviceStatus> getStatus() async => _status;

  @override
  Future<DeviceLocation> getLocation() async => _location;

  @override
  Future<void> sendNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    sentNotifications.add({
      'id': id ?? sentNotifications.length + 1,
      'title': title,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> vibrate({int durationMs = 200}) async {
    // Vibrate simulation
  }
}

/// Function signature for delegating device capability queries across a platform bridge.
typedef NativeDeviceBridge = Future<dynamic> Function(
  String action, [
  Map<String, dynamic>? params,
]);

/// Device harness that routes device queries and actions through a native platform bridge callback
/// (e.g. Android MethodChannel via DeviceHarnessBridge.kt).
class NativeBridgeDeviceHarness implements DeviceHarness {
  final NativeDeviceBridge _bridge;
  DeviceLocation? _cachedLocation;

  NativeBridgeDeviceHarness(this._bridge);

  @override
  Future<DeviceStatus> getStatus() async {
    try {
      final batteryRes = await _bridge('getBatteryInfo');
      final networkRes = await _bridge('getNetworkStatus');

      final batteryMap = batteryRes is Map
          ? Map<String, dynamic>.from(batteryRes)
          : <String, dynamic>{};
      final batteryLevel =
          (batteryMap['batteryLevel'] as num?)?.toDouble() ?? 1.0;
      final isCharging = batteryMap['isCharging'] as bool? ?? false;
      final networkType = networkRes?.toString() ?? 'wifi';

      return DeviceStatus(
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        networkType: networkType,
      );
    } catch (_) {
      return const DeviceStatus();
    }
  }

  @override
  Future<DeviceLocation> getLocation() async {
    if (_cachedLocation != null) return _cachedLocation!;
    try {
      final res = await _bridge('getLocation');
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        final lat = (map['latitude'] as num?)?.toDouble() ?? 0.0;
        final lng = (map['longitude'] as num?)?.toDouble() ?? 0.0;
        final acc = (map['accuracyMeters'] as num?)?.toDouble() ?? 10.0;
        _cachedLocation = DeviceLocation(
          latitude: lat,
          longitude: lng,
          accuracyMeters: acc,
        );
        return _cachedLocation!;
      }
    } catch (_) {}
    return DeviceLocation(latitude: 0.0, longitude: 0.0);
  }

  @override
  Future<void> sendNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    await _bridge('showNotification', {
      'title': title,
      'content': body,
      'channelId': 'mobi_nooa_channel',
      'notificationId': id ?? 1001,
    });
  }

  @override
  Future<void> vibrate({int durationMs = 200}) async {
    await _bridge('vibrate', {'durationMs': durationMs});
  }
}

