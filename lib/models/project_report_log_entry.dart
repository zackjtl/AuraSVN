import 'package:aura_svn/utils/helpers.dart';

class ProjectReportLogEntry {
  const ProjectReportLogEntry({
    required this.level,
    required this.message,
    required this.time,
  });

  factory ProjectReportLogEntry.fromJson(Map<String, dynamic> json) {
    return ProjectReportLogEntry(
      level: json['level']?.toString() ?? 'info',
      message: json['message']?.toString() ?? '',
      time: parseDateTime(json['time']) ?? DateTime.now(),
    );
  }

  final String level;
  final String message;
  final DateTime time;
}
