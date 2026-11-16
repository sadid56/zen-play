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
    final avatar = CircleAvatar(
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

    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}
