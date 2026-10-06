// lib/models/schedule.dart
class Schedule {
  final List<int> weekdays;
  final String startTime; // Formato: "18:00"
  final String endTime;   // Formato: "19:00"

  Schedule({
    required this.weekdays,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
    'weekdays': weekdays,
    'start': startTime,
    'end': endTime,
  };

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
    weekdays: List<int>.from(json['weekdays']),
    startTime: json['start'],
    endTime: json['end'],
  );
}