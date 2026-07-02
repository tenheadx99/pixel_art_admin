/// Per-flavor app config stored at `pixel_art/{flavor}/config/app`.
/// Absent/empty fields mean "no override".
class AppVersionConfig {
  final String? minVersion;
  final String? forceUpdateUrl;

  /// Kill-switch: the app shows a blocking "back soon" screen while true.
  final bool maintenance;
  final String? maintenanceMessage;

  const AppVersionConfig({
    this.minVersion,
    this.forceUpdateUrl,
    this.maintenance = false,
    this.maintenanceMessage,
  });

  factory AppVersionConfig.fromMap(Map<String, dynamic> map) {
    return AppVersionConfig(
      minVersion: _nonEmpty(map['minVersion']),
      forceUpdateUrl: _nonEmpty(map['forceUpdateUrl']),
      maintenance: map['maintenance'] == true,
      maintenanceMessage: _nonEmpty(map['maintenanceMessage']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (minVersion != null) 'minVersion': minVersion,
      if (forceUpdateUrl != null) 'forceUpdateUrl': forceUpdateUrl,
      'maintenance': maintenance,
      if (maintenanceMessage != null) 'maintenanceMessage': maintenanceMessage,
    };
  }

  static String? _nonEmpty(Object? v) {
    final s = v as String?;
    return (s == null || s.isEmpty) ? null : s;
  }
}
