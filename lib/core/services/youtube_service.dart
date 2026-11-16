import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';

class PlaybackDetails {
  const PlaybackDetails({
    this.streamUrl,
    this.qualityStreams = const {},
    this.description,
    this.likesCount,
    this.dislikesCount,
    this.isLive = false,
    this.sponsorSegments = const [],
    this.comments = const [],
  });

  final String? streamUrl;
  final Map<String, String> qualityStreams;
  final String? description;
  final String? likesCount;
  final String? dislikesCount;
  final bool isLive;
  final List<SponsorSegment> sponsorSegments;
  final List<CommentItem> comments;
}

class YoutubeService {
  YoutubeService({
    YoutubeExplode? explode,
    http.Client? httpClient,
  })  : _yt = explode ?? YoutubeExplode(),
        _http = httpClient ?? http.Client();

  final YoutubeExplode _yt;
  final http.Client _http;

  static const Map<String, String> _categoryQueries = {
    'All': 'latest music songs and tech videos',
    'Tech': 'flutter programming tech review',
    'Music': 'latest official music video',
    'Design': 'material design ui ux',
    'Gaming': 'gaming gameplay showcase',
    'Podcasts': 'tech podcast interview',
  };

  Future<List<VideoItem>> fetchFeed(String category) async {
    final query = _categoryQueries[category] ?? category;
    return searchVideos(query, category: category);
  }

  Future<List<VideoItem>> searchVideos(
    String query, {
    String category = 'All',
  }) async {
    try {
      final list = await _yt.search.search(query).timeout(const Duration(seconds: 10));
      if (list.isNotEmpty) {
        return list.take(15).map((v) => _mapVideo(v, category)).toList();
      }
    } catch (_) {}

    return _innerTubeSearch(query, category: category);
  }

  Future<List<VideoItem>> _innerTubeSearch(
    String query, {
    String category = 'All',
  }) async {
    try {
      final uri = Uri.https('www.youtube.com', '/youtubei/v1/search');
      final response = await _http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'context': {
                'client': {
                  'clientName': 'WEB',
                  'clientVersion': '2.20241114.01.00',
                  'hl': 'en',
                  'gl': 'US',
                },
              },
              'query': query,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return const [];
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final results = <VideoItem>[];
      _collectVideoRenderers(root, results, category);
      return results.take(15).toList();
    } catch (_) {
      return const [];
    }
  }

  void _collectVideoRenderers(
    dynamic node,
    List<VideoItem> out,
    String category,
  ) {
    if (out.length >= 15) return;
    if (node is Map<String, dynamic>) {
      final vr = node['videoRenderer'];
      if (vr is Map<String, dynamic>) {
        final mapped = _mapInnerTubeRenderer(vr, category);
        if (mapped != null) out.add(mapped);
        return;
      }
      for (final value in node.values) {
        _collectVideoRenderers(value, out, category);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectVideoRenderers(item, out, category);
      }
    }
  }

  VideoItem? _mapInnerTubeRenderer(Map<String, dynamic> vr, String category) {
    final videoId = vr['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) return null;

    final title = _readRuns(vr['title']) ?? 'Untitled';
    final channelName = _readRuns(vr['ownerText']) ??
        _readRuns(vr['longBylineText']) ??
        'YouTube';
    final channelId = _readBrowseId(vr['ownerText']) ?? channelName;
    final duration = _readSimpleText(vr['lengthText']) ?? 'LIVE';
    final views = _readSimpleText(vr['shortViewCountText']) ??
        _readSimpleText(vr['viewCountText']) ??
        '';
    final published = _readSimpleText(vr['publishedTimeText']) ?? 'Recently';
    final thumbs = (vr['thumbnail']?['thumbnails'] as List?) ?? const [];
    final thumbUrl = thumbs.isNotEmpty
        ? (thumbs.last['url'] as String?)
        : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

    return VideoItem(
      id: videoId,
      title: title,
      channel: ChannelInfo(
        id: channelId,
        name: channelName,
        handle: '@${channelName.replaceAll(' ', '').toLowerCase()}',
        subscriberCount: 'YouTube channel',
        avatarColorValue: _colorForId(channelId),
      ),
      duration: duration,
      durationSeconds: _parseDurationSeconds(duration),
      viewsText: views.isEmpty ? 'YouTube' : views,
      publishedAgo: published,
      category: category,
      description: '',
      likesCount: '—',
      dislikesCount: '—',
      accentColorValue: _colorForId(videoId),
      thumbnailUrl: thumbUrl,
      isLive: duration == 'LIVE',
    );
  }

  static String? _readRuns(dynamic obj) {
    if (obj is! Map<String, dynamic>) return null;
    final simple = obj['simpleText'] as String?;
    if (simple != null) return simple;
    final runs = obj['runs'] as List?;
    if (runs == null || runs.isEmpty) return null;
    return runs.map((r) => (r['text'] as String?) ?? '').join();
  }

  static String? _readSimpleText(dynamic obj) {
    if (obj is! Map<String, dynamic>) return null;
    return (obj['simpleText'] as String?) ?? _readRuns(obj);
  }

  static String? _readBrowseId(dynamic obj) {
    if (obj is! Map<String, dynamic>) return null;
    final runs = obj['runs'] as List?;
    if (runs == null || runs.isEmpty) return null;
    return runs.first['navigationEndpoint']?['browseEndpoint']?['browseId']
        as String?;
  }

  static int _parseDurationSeconds(String label) {
    final parts = label.split(':').map(int.tryParse).toList();
    if (parts.any((p) => p == null)) return 0;
    if (parts.length == 2) return parts[0]! * 60 + parts[1]!;
    if (parts.length == 3) return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
    return 0;
  }

  Future<List<VideoItem>> fetchChannelVideos(String channelId) async {
    try {
      final uploads = await _yt.channels.getUploads(channelId).take(12).toList();
      if (uploads.isNotEmpty) {
        return uploads.map((v) => _mapVideo(v, 'All')).toList();
      }
    } catch (_) {}
    return searchVideos(channelId);
  }

  Future<PlaybackDetails> resolvePlaybackDetails(String videoId) async {
    final results = await Future.wait([
      _fetchVideoMeta(videoId),
      _fetchSponsorSegments(videoId),
      _fetchReturnDislike(videoId),
      _fetchComments(videoId),
    ]);

    final meta = results[0] as ({String? description, String? likes, bool isLive})?;
    final segments = results[1] as List<SponsorSegment>;
    final ryd = results[2] as ({String? likes, String? dislikes})?;
    final comments = results[3] as List<CommentItem>;

    return PlaybackDetails(
      description: meta?.description,
      likesCount: ryd?.likes ?? meta?.likes,
      dislikesCount: ryd?.dislikes,
      isLive: meta?.isLive ?? false,
      sponsorSegments: segments,
      comments: comments,
    );
  }

  Future<({String? description, String? likes, bool isLive})?> _fetchVideoMeta(
    String videoId,
  ) async {
    try {
      final video = await _yt.videos.get(videoId).timeout(const Duration(seconds: 6));
      return (
        description: video.description,
        likes: _formatCompactCount(video.engagement.likeCount),
        isLive: video.isLive,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<SponsorSegment>> _fetchSponsorSegments(String videoId) async {
    try {
      final uri = Uri.https(
        'sponsor.ajay.app',
        '/api/skipSegments',
        {'videoID': videoId},
      );
      final response = await _http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      return decoded.map((item) {
        final segment = (item['segment'] as List?) ?? const [0, 0];
        return SponsorSegment(
          startSeconds: (segment[0] as num).toDouble(),
          endSeconds: (segment[1] as num).toDouble(),
          category: (item['category'] as String?) ?? 'sponsor',
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<({String? likes, String? dislikes})?> _fetchReturnDislike(String videoId) async {
    try {
      final uri = Uri.https(
        'returnyoutubedislikeapi.com',
        '/votes',
        {'videoId': videoId},
      );
      final response = await _http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        likes: _formatCompactCount(decoded['likes'] as int?),
        dislikes: _formatCompactCount(decoded['dislikes'] as int?),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<CommentItem>> _fetchComments(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId).timeout(const Duration(seconds: 6));
      final commentsList =
          await _yt.videos.comments.getComments(video).timeout(const Duration(seconds: 6));
      if (commentsList == null) return const [];

      return commentsList.take(25).map((c) {
        return CommentItem(
          id: '${c.author}_${c.publishedTime}',
          author: c.author,
          text: c.text,
          publishedAgo: c.publishedTime,
          likes: _formatCompactCount(c.likeCount) ?? '0',
          replyCount: c.replyCount,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  VideoItem _mapVideo(Video v, String category) {
    final duration = v.duration ?? Duration.zero;
    return VideoItem(
      id: v.id.value,
      title: v.title,
      channel: ChannelInfo(
        id: v.channelId.value,
        name: v.author,
        handle: '@${v.author.replaceAll(' ', '').toLowerCase()}',
        subscriberCount: 'YouTube channel',
        avatarColorValue: _colorForId(v.channelId.value),
      ),
      duration: _formatDuration(duration),
      durationSeconds: duration.inSeconds,
      viewsText: '${_formatCompactCount(v.engagement.viewCount) ?? '0'} views',
      publishedAgo: v.uploadDateRaw ?? 'Recently',
      category: category,
      description: v.description,
      likesCount: _formatCompactCount(v.engagement.likeCount) ?? '—',
      dislikesCount: '—',
      accentColorValue: _colorForId(v.id.value),
      thumbnailUrl: v.thumbnails.highResUrl,
      isLive: v.isLive,
    );
  }

  static int _colorForId(String id) {
    const palette = [
      0xFF1E2A78,
      0xFF0277BD,
      0xFF00796B,
      0xFF5E35B1,
      0xFFD84315,
      0xFF283593,
    ];
    return palette[id.hashCode.abs() % palette.length];
  }

  static String _formatDuration(Duration d) {
    if (d == Duration.zero) return 'LIVE';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String? _formatCompactCount(int? count) {
    if (count == null) return null;
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  void dispose() {
    _yt.close();
    _http.close();
  }
}
