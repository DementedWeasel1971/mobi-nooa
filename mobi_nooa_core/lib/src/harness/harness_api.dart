import 'device_harness.dart';
import 'filesystem_harness.dart';
import 'network_harness.dart';
import 'memory_harness.dart';
import 'mcp_harness.dart';
import 'sqlite_harness.dart';

/// Unified model-callable Harness API for modern Android mobile devices.
///
/// Implements NOOA Principle 6: "Model-callable harness APIs".
/// Exposes system, hardware, storage, and networking interfaces as first-class,
/// strongly-typed Dart objects.
class HarnessApi {
  final DeviceHarness device;
  final FileSystemHarness fs;
  final NetworkHarness network;
  final MemoryHarness memory;
  final McpHarness mcp;
  final SqliteHarness sqlite;

  HarnessApi({
    DeviceHarness? device,
    FileSystemHarness? fs,
    NetworkHarness? network,
    MemoryHarness? memory,
    McpHarness? mcp,
    SqliteHarness? sqlite,
  })  : device = device ?? DefaultDeviceHarness(),
        fs = fs ?? MemoryFileSystemHarness(),
        network = network ?? DefaultNetworkHarness(),
        memory = memory ?? DefaultMemoryHarness(),
        mcp = mcp ?? DefaultMcpHarness(),
        sqlite = sqlite ?? InMemorySqliteHarness();
}
