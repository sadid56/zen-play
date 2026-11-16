import 'package:flutter/material.dart';
import 'package:zenplay/core/models/channel_info.dart';

class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({
    super.key,
    required this.channel,
    this.radius = 20,
    this.onTap,
  });

  final ChannelInfo channel;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: Color(channel.avatarColorValue),
      foregroundColor: Colors.white,
      child: Text(
        channel.initials,
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final url = channel.avatarUrl;
    final avatar = url != null && url.isNotEmpty
        ? ClipOval(
            child: Image.network(
              url,
              width: radius * 2,
              height: radius * 2,
              cacheWidth: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
          )
        : fallback;

    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}
