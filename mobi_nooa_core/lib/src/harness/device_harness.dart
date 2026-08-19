import 'dart:async';

/// Device state snapshot (battery, network, sensors, memory).
class DeviceStatus {
  final double batteryLevel; // 0.0 to 1.0
  final bool isCharging;
  final String networkType; // 'wifi', 'cellular', 'none'
  final bool isLowPowerMode;
  final int freeDiskSpaceMb;
  final int totalDiskSpaceMb;

  const DeviceStatus({
    this.batteryLevel = 0.85,
    this.isCharging = false,
    this.networkType = 'wifi',
    this.isLowPowerMode = false,
    this.freeDiskSpaceMb = 12400,
    this.totalDiskSpaceMb = 128000,
  });

  Map<String, dynamic> toJson() => {
        'batteryLevel': batteryLevel,
        'isCharging': isCharging,
        'networkType': networkType,
        'isLowPowerMode': isLowPowerMode,
        'freeDiskSpaceMb': freeDiskSpaceMb,
        'totalDiskSpaceMb': totalDiskSpaceMb,
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
