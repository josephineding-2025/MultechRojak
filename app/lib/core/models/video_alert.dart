class VideoAlert {
  final bool alert;
  final String reason;
  final String severity;

  const VideoAlert({
    required this.alert,
    required this.reason,
    required this.severity,
  });

  factory VideoAlert.fromJson(Map<String, dynamic> json) => VideoAlert(
        alert: json['alert'] as bool,
        reason: json['reason'] as String,
        severity: json['severity'] as String,
      );
}

class AudioAlert {
  final String transcription;
  final bool alert;
  final String reason;
  final String severity;

  const AudioAlert({
    required this.transcription,
    required this.alert,
    required this.reason,
    required this.severity,
  });

  factory AudioAlert.fromJson(Map<String, dynamic> json) => AudioAlert(
        transcription: json['transcription'] as String,
        alert: json['alert'] as bool,
        reason: json['reason'] as String,
        severity: json['severity'] as String,
      );
}
