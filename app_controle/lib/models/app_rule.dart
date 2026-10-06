// lib/models/app_rule.dart
import 'schedule.dart';

class AppRule {
  final String packageName;
  final String appName;
  final String? iconPath; // caminho local do ícone salvo em disco
  final List<Schedule> schedules;

  AppRule({
    required this.packageName,
    required this.appName,
    this.iconPath,
    required this.schedules,
  });

  AppRule copyWith({
    String? packageName,
    String? appName,
    String? iconPath,
    List<Schedule>? schedules,
  }) {
    return AppRule(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      iconPath: iconPath ?? this.iconPath,
      schedules: schedules ?? this.schedules,
    );
  }

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        'iconPath': iconPath,
        'schedules': schedules.map((s) => s.toJson()).toList(),
      };

  factory AppRule.fromJson(Map<String, dynamic> json) => AppRule(
        packageName: json['packageName'],
        appName: json['appName'],
        iconPath: json['iconPath'],
        schedules: (json['schedules'] as List)
            .map((s) => Schedule.fromJson(s))
            .toList(),
      );
}