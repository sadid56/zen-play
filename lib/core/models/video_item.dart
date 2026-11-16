import 'package:zenplay/core/models/channel_info.dart';

class ChapterItem {
  const ChapterItem({
    required this.title,
    required this.timestamp,
    required this.seconds,
  });

  final String title;
  final String timestamp;
  final int seconds;
}

class SponsorSegment {
  const SponsorSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.category,
  });

  final double startSeconds;
  final double endSeconds;
  final String category;
}

class CommentItem {
  const CommentItem({
    required this.id,
    required this.author,
    required this.text,
    required this.publishedAgo,
    required this.likes,
    this.replyCount = 0,
  });

  final String id;
  final String author;
  final String text;
  final String publishedAgo;
  final String likes;
  final int replyCount;
}

class LiveChatMessage {
  const LiveChatMessage({
    required this.author,
    required this.message,
    required this.timestampLabel,
  });

  final String author;
  final String message;
  final String timestampLabel;
}

class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.channel,
    required this.duration,
    required this.durationSeconds,
    required this.viewsText,
    required this.publishedAgo,
    required this.category,
    required this.description,
    required this.likesCount,
    required this.dislikesCount,
    required this.accentColorValue,
    this.thumbnailUrl,
    this.isLive = false,
    this.hasSponsorBlock = false,
    this.hasDeArrowTitle = false,
    this.chapters = const [],
    this.comments = const [],
  });

  final String id;
  final String title;
  final ChannelInfo channel;
  final String duration;
  final int durationSeconds;
  final String viewsText;
  final String publishedAgo;
  final String category;
  final String description;
  final String likesCount;
  final String dislikesCount;
  final int accentColorValue;
  final String? thumbnailUrl;
  final bool isLive;
  final bool hasSponsorBlock;
  final bool hasDeArrowTitle;
  final List<ChapterItem> chapters;
  final List<CommentItem> comments;

  VideoItem copyWith({
    String? likesCount,
    String? dislikesCount,
    String? description,
    bool? isLive,
    bool? hasSponsorBlock,
    List<CommentItem>? comments,
  }) {
    return VideoItem(
      id: id,
      title: title,
      channel: channel,
      duration: duration,
      durationSeconds: durationSeconds,
      viewsText: viewsText,
      publishedAgo: publishedAgo,
      category: category,
      description: description ?? this.description,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      accentColorValue: accentColorValue,
      thumbnailUrl: thumbnailUrl,
      isLive: isLive ?? this.isLive,
      hasSponsorBlock: hasSponsorBlock ?? this.hasSponsorBlock,
      hasDeArrowTitle: hasDeArrowTitle,
      chapters: chapters,
      comments: comments ?? this.comments,
    );
  }
}
