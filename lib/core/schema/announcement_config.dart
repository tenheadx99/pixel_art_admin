/// In-app announcement banner stored at
/// `pixel_art/{flavor}/config/announcement`. The [stamp] changes on every
/// save so a previously dismissed banner re-appears when edited.
class AnnouncementConfig {
  final bool enabled;
  final String title;
  final String message;
  final String? linkUrl;
  final int stamp;

  const AnnouncementConfig({
    this.enabled = false,
    this.title = '',
    this.message = '',
    this.linkUrl,
    this.stamp = 0,
  });

  factory AnnouncementConfig.fromMap(Map<String, dynamic> map) {
    final link = map['linkUrl'] as String?;
    return AnnouncementConfig(
      enabled: map['enabled'] == true,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      linkUrl: (link == null || link.isEmpty) ? null : link,
      stamp: (map['stamp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'title': title,
      'message': message,
      if (linkUrl != null) 'linkUrl': linkUrl,
      'stamp': stamp,
    };
  }
}
