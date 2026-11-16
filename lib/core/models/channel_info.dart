class ChannelInfo {
  const ChannelInfo({
    required this.id,
    required this.name,
    required this.handle,
    required this.subscriberCount,
    required this.avatarColorValue,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final String handle;
  final String subscriberCount;
  final int avatarColorValue;
  final bool isVerified;

  ChannelInfo copyWith({String? subscriberCount}) {
    return ChannelInfo(
      id: id,
      name: name,
      handle: handle,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      avatarColorValue: avatarColorValue,
      isVerified: isVerified,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Z';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}
