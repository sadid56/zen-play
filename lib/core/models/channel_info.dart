class ChannelInfo {
  const ChannelInfo({
    required this.id,
    required this.name,
    required this.handle,
    required this.subscriberCount,
    required this.avatarColorValue,
    this.avatarUrl,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final String handle;
  final String subscriberCount;
  final int avatarColorValue;
  final String? avatarUrl;
  final bool isVerified;

  ChannelInfo copyWith({
    String? subscriberCount,
    String? avatarUrl,
  }) {
    return ChannelInfo(
      id: id,
      name: name,
      handle: handle,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      avatarColorValue: avatarColorValue,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'handle': handle,
        'subscriberCount': subscriberCount,
        'avatarColorValue': avatarColorValue,
        'avatarUrl': avatarUrl,
        'isVerified': isVerified,
      };

  factory ChannelInfo.fromJson(Map<String, dynamic> json) {
    return ChannelInfo(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'YouTube',
      handle: (json['handle'] as String?) ?? '@youtube',
      subscriberCount: (json['subscriberCount'] as String?) ?? 'YouTube channel',
      avatarColorValue: (json['avatarColorValue'] as int?) ?? 0xFF1E2A78,
      avatarUrl: json['avatarUrl'] as String?,
      isVerified: (json['isVerified'] as bool?) ?? false,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Z';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}
