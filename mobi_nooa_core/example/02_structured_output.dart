import 'dart:convert';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// Structured telemetry record returned by the model.
class SystemHealthReport {
  final String status;
  final int batteryPercent;
  final bool requiresPowerSave;

  SystemHealthReport({
    required this.status,
    required this.batteryPercent,
    required this.requiresPowerSave,
  });

  factory SystemHealthReport.fromJson(Map<String, dynamic> json) =>
      SystemHealthReport(
        status: json['status'] as String,
        batteryPercent: json['batteryPercent'] as int,
        requiresPowerSave: json['requiresPowerSave'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'batteryPercent': batteryPercent,
        'requiresPowerSave': requiresPowerSave,
      };

  @override
  String toString() =>
      'HealthReport(status: $status, battery: $batteryPercent%, powerSave: $requiresPowerSave)';
}

/// 02: Structured Output Generation
class DiagnosticAgent extends NooaAgent {
  DiagnosticAgent()
      : super(
          name: 'DiagnosticAgent',
          role: 'Mobile System Diagnostics',
          description: 'Evaluates system state and returns typed health reports.',
        );

  Future<SystemHealthReport> evaluateHealth(int batteryLevel) async {
    final rawJson = await ellipsis<String>(
      'Return a JSON object conforming to schema {"status": string, "batteryPercent": int, "requiresPowerSave": bool} for battery level $batteryLevel.',
    );
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    return SystemHealthReport.fromJson(map);
  }
}

Future<void> main() async {
  print('=== mobi-nooa Tutorial 02: Structured Output ===\n');

  final mockModel = MockModelClient();
  mockModel.queueText('{"status": "optimal", "batteryPercent": 88, "requiresPowerSave": false}');

  final agent = Quickstart.createAgent(
    () => DiagnosticAgent(),
    model: mockModel,
  );

  final report = await agent.evaluateHealth(88);
  print('Structured Report Object:');
  print(report);
  print('Is Power Save Required? ${report.requiresPowerSave}');
}
