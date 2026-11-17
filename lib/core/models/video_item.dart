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
    this.avatarUrl,
    this.replyCount = 0,
    this.repliesToken,
    this.replies = const [],
  });

  final String id;
  final String author;
  final String text;
  final String publishedAgo;
  final String likes;
  final String? avatarUrl;
  final int replyCount;
  final String? repliesToken;
  final List<CommentItem> replies;

  CommentItem copyWith({List<CommentItem>? replies}) {
    return CommentItem(
      id: id,
      author: author,
      text: text,
      publishedAgo: publishedAgo,
      likes: likes,
      avatarUrl: avatarUrl,
      replyCount: replyCount,
      repliesToken: repliesToken,
      replies: replies ?? this.replies,
    );
  }
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
    this.totalCommentsCount,
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
  final String? totalCommentsCount;
  final bool isLive;
  final bool hasSponsorBlock;
  final bool hasDeArrowTitle;
  final List<ChapterItem> chapters;
  final List<CommentItem> comments;

  VideoItem copyWith({
    ChannelInfo? channel,
    String? viewsText,
    String? likesCount,
    String? dislikesCount,
    String? description,
    String? totalCommentsCount,
    bool? isLive,
    bool? hasSponsorBlock,
    List<CommentItem>? comments,
  }) {
    return VideoItem(
      id: id,
      title: title,
      channel: channel ?? this.channel,
      duration: duration,
      durationSeconds: durationSeconds,
      viewsText: viewsText ?? this.viewsText,
      publishedAgo: publishedAgo,
      category: category,
      description: description ?? this.description,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      accentColorValue: accentColorValue,
      thumbnailUrl: thumbnailUrl,
      totalCommentsCount: totalCommentsCount ?? this.totalCommentsCount,
      isLive: isLive ?? this.isLive,
      hasSponsorBlock: hasSponsorBlock ?? this.hasSponsorBlock,
      hasDeArrowTitle: hasDeArrowTitle,
      chapters: chapters,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'channel': channel.toJson(),
        'duration': duration,
        'durationSeconds': durationSeconds,
        'viewsText': viewsText,
        'publishedAgo': publishedAgo,
        'category': category,
        'description': description,
        'likesCount': likesCount,
        'dislikesCount': dislikesCount,
        'accentColorValue': accentColorValue,
        'thumbnailUrl': thumbnailUrl,
        'totalCommentsCount': totalCommentsCount,
        'isLive': isLive,
      };

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      channel: ChannelInfo.fromJson(
        (json['channel'] as Map<String, dynamic>?) ?? const {},
      ),
      duration: (json['duration'] as String?) ?? '0:00',
      durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      viewsText: (json['viewsText'] as String?) ?? '',
      publishedAgo: (json['publishedAgo'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'All',
      description: (json['description'] as String?) ?? '',
      likesCount: (json['likesCount'] as String?) ?? '—',
      dislikesCount: (json['dislikesCount'] as String?) ?? '—',
      accentColorValue: (json['accentColorValue'] as int?) ?? 0xFF1E2A78,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      totalCommentsCount: json['totalCommentsCount'] as String?,
      isLive: (json['isLive'] as bool?) ?? false,
    );
  }
}
