import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';

class CommentsPage {
  const CommentsPage({
    this.comments = const [],
    this.nextToken,
  });

  final List<CommentItem> comments;
  final String? nextToken;
}

class PlaybackDetails {
  const PlaybackDetails({
    this.description,
    this.likesCount,
    this.dislikesCount,
    this.subscriberCount,
    this.channelAvatarUrl,
    this.isLive = false,
    this.availableQualities = const ['Auto'],
    this.sponsorSegments = const [],
    this.comments = const [],
    this.commentsNextToken,
    this.totalCommentsCount,
    this.liveChatMessages = const [],
  });

  final String? description;
  final String? likesCount;
  final String? dislikesCount;
  final String? subscriberCount;
  final String? channelAvatarUrl;
  final bool isLive;
  final List<String> availableQualities;
  final List<SponsorSegment> sponsorSegments;
  final List<CommentItem> comments;
  final String? commentsNextToken;
  final String? totalCommentsCount;
  final List<LiveChatMessage> liveChatMessages;
}

class YoutubeService {
  YoutubeService({
    YoutubeExplode? explode,
    http.Client? httpClient,
  })  : _yt = explode ?? YoutubeExplode(),
        _http = httpClient ?? http.Client();

  final YoutubeExplode _yt;
  final http.Client _http;

  static const Map<String, List<String>> _categoryQueries = {
    'All': [
      'latest music songs and tech videos',
      'popular science documentary 4k',
      'trending live acoustic session',
      'creative filmmaking breakdown',
      'new indie music releases',
      'world travel 4k hdr film',
      'modern architecture tour',
    ],
    'Live': [
      'live stream',
      'lofi hip hop radio live',
      'live news world',
      'live music concert stream',
      'live nature wildlife cam',
    ],
    'Tech': [
      'flutter programming tech review',
      'software architecture engineering talk',
      'linux open source hardware review',
      'new smartphone camera comparison',
      'ai robotics engineering demo',
    ],
    'Music': [
      'latest official music video',
      'chill ambient lofi beats',
      'acoustic live studio session',
      'electronic synthwave live set',
      'indie pop new release',
    ],
    'Design': [
      'material design ui ux',
      'motion design typography tutorial',
      'industrial product design process',
      '3d blender stylized art',
    ],
    'Gaming': [
      'gaming gameplay showcase',
      'indie game devlog',
      'retro game soundtrack',
      'open world game 4k walkthrough',
    ],
    'Podcasts': [
      'tech podcast interview',
      'founder engineering podcast',
      'science philosophy podcast',
      'creative storytelling podcast',
    ],
  };

  Future<List<VideoItem>> fetchFeed(String category, {int page = 0}) async {
    final queries = _categoryQueries[category] ?? [category];
    final query = queries[page % queries.length];
    return searchVideos(query, category: category);
  }

  Future<List<String>> fetchSearchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final uri = Uri.https(
        'suggestqueries.google.com',
        '/complete/search',
        {
          'client': 'firefox',
          'ds': 'yt',
          'q': trimmed,
        },
      );
      final response = await _http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is List && decoded.length > 1 && decoded[1] is List) {
        return (decoded[1] as List).whereType<String>().take(8).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<VideoItem>> searchVideos(
    String query, {
    String category = 'All',
  }) async {
    final innerTube = await _innerTubeSearch(
      query,
      category: category,
      liveOnly: category == 'Live',
    );
    if (innerTube.isNotEmpty) return innerTube;

    try {
      final list = await _yt.search.search(query).timeout(const Duration(seconds: 10));
      if (list.isNotEmpty) {
        return list.take(15).map((v) => _mapVideo(v, category)).toList();
      }
    } catch (_) {}

    return const [];
  }

  Future<List<VideoItem>> _innerTubeSearch(
    String query, {
    String category = 'All',
    bool liveOnly = false,
  }) async {
    try {
      final uri = Uri.https('www.youtube.com', '/youtubei/v1/search');
      final body = <String, dynamic>{
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20241114.01.00',
            'hl': 'en',
            'gl': 'US',
          },
        },
        'query': query,
      };
      if (liveOnly) {
        body['params'] = 'EgJAAQ==';
      }
      final response = await _http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
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
    final channelId = _readBrowseId(vr['ownerText']) ??
        _readBrowseId(vr['longBylineText']) ??
        channelName;
    final durationText = _readSimpleText(vr['lengthText']);
    final isLive = durationText == null || _hasLiveBadge(vr);
    final duration = isLive ? 'LIVE' : durationText;
    final views = _readSimpleText(vr['shortViewCountText']) ??
        _readSimpleText(vr['viewCountText']) ??
        '';
    final published = _readSimpleText(vr['publishedTimeText']) ?? 'Recently';
    final thumbs = (vr['thumbnail']?['thumbnails'] as List?) ?? const [];
    final thumbUrl = thumbs.isNotEmpty
        ? (thumbs.last['url'] as String?)
        : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    final avatarThumbs = (vr['channelThumbnailSupportedRenderers']
            ?['channelThumbnailWithLinkRenderer']?['thumbnail']?['thumbnails']
        as List?) ??
        const [];
    final avatarUrl =
        avatarThumbs.isNotEmpty ? (avatarThumbs.last['url'] as String?) : null;

    return VideoItem(
      id: videoId,
      title: title,
      channel: ChannelInfo(
        id: channelId,
        name: channelName,
        handle: '@${channelName.replaceAll(' ', '').toLowerCase()}',
        subscriberCount: 'YouTube channel',
        avatarColorValue: _colorForId(channelId),
        avatarUrl: avatarUrl,
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
      isLive: isLive,
    );
  }

  static bool _hasLiveBadge(Map<String, dynamic> vr) {
    final badges = vr['badges'] as List?;
    if (badges != null) {
      for (final b in badges) {
        final style = b['metadataBadgeRenderer']?['style'] as String?;
        if (style == 'BADGE_STYLE_TYPE_LIVE_NOW') return true;
      }
    }
    final overlays = vr['thumbnailOverlays'] as List?;
    if (overlays != null) {
      for (final o in overlays) {
        final style = o['thumbnailOverlayTimeStatusRenderer']?['style'] as String?;
        if (style == 'LIVE') return true;
      }
    }
    return false;
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

  Future<String?> fetchChannelSubscribers(String channelId) async {
    try {
      final channel =
          await _yt.channels.get(channelId).timeout(const Duration(seconds: 6));
      final subs = channel.subscribersCount;
      if (subs != null) {
        return '${_formatCompactCount(subs)} subscribers';
      }
    } catch (_) {}

    if (!channelId.startsWith('UC')) return null;
    try {
      final response = await _http
          .post(
            Uri.https('www.youtube.com', '/youtubei/v1/browse'),
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
              'browseId': channelId,
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      return _findSubscriberCount(jsonDecode(response.body));
    } catch (_) {
      return null;
    }
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

  Future<PlaybackDetails> resolvePlaybackDetails(
    String videoId, {
    String? channelId,
    bool isLiveHint = false,
  }) async {
    final results = await Future.wait([
      _fetchVideoMeta(videoId),
      _fetchSponsorSegments(videoId),
      _fetchReturnDislike(videoId),
      _fetchComments(videoId),
      if (channelId != null && channelId.startsWith('UC'))
        fetchChannelSubscribers(channelId)
      else
        Future<String?>.value(null),
      if (isLiveHint)
        _innerTubeLiveChat(videoId)
      else
        Future<List<LiveChatMessage>>.value(const []),
      _fetchAvailableQualities(videoId),
    ]);

    final meta = results[0] as ({String? description, String? likes, bool isLive, String? channelId})?;
    final segments = results[1] as List<SponsorSegment>;
    final ryd = results[2] as ({String? likes, String? dislikes})?;
    final commentsPage = results[3] as CommentsPage;
    var subs = results[4] as String?;
    var liveChat = results[5] as List<LiveChatMessage>;
    final qualities = results[6] as List<String>;

    if (subs == null && meta?.channelId != null) {
      subs = await fetchChannelSubscribers(meta!.channelId!);
    }
    final watchOwner = await _fetchWatchOwnerInfo(videoId);
    subs ??= watchOwner?.subscribers;
    final channelAvatarUrl = watchOwner?.avatarUrl;
    final isLive = meta?.isLive ?? isLiveHint;
    if (isLive && liveChat.isEmpty && !isLiveHint) {
      liveChat = await _innerTubeLiveChat(videoId);
    }

    return PlaybackDetails(
      description: meta?.description,
      likesCount: ryd?.likes ?? meta?.likes,
      dislikesCount: ryd?.dislikes,
      subscriberCount: subs,
      channelAvatarUrl: channelAvatarUrl,
      isLive: isLive,
      availableQualities: qualities,
      sponsorSegments: segments,
      comments: commentsPage.comments,
      commentsNextToken: commentsPage.nextToken,
      totalCommentsCount: watchOwner?.totalComments,
      liveChatMessages: liveChat,
    );
  }

  Future<List<String>> _fetchAvailableQualities(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 6));
      final heights = <int>{};
      for (final s in manifest.videoOnly) {
        final h = s.videoResolution.height;
        if (h > 0) heights.add(h);
      }
      for (final s in manifest.muxed) {
        final h = s.videoResolution.height;
        if (h > 0) heights.add(h);
      }
      final sorted = heights.toList()..sort((a, b) => b.compareTo(a));
      return ['Auto', ...sorted.map((h) => '${h}p')];
    } catch (_) {
      return const ['Auto', '1080p', '720p', '480p', '360p'];
    }
  }

  Future<({String? subscribers, String? avatarUrl, String? totalComments})?>
      _fetchWatchOwnerInfo(String videoId) async {
    try {
      final res = await _http
          .post(
            Uri.https('www.youtube.com', '/youtubei/v1/next'),
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
              'videoId': videoId,
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      return (
        subscribers: _findSubscriberCount(json),
        avatarUrl: _findOwnerAvatarUrl(json),
        totalComments: _findTotalCommentsCount(json),
      );
    } catch (_) {
      return null;
    }
  }

  String? _findTotalCommentsCount(dynamic node) {
    if (node is Map<String, dynamic>) {
      final header = node['commentsEntryPointHeaderRenderer'];
      if (header is Map<String, dynamic>) {
        final count = _readSimpleText(header['commentCount']);
        if (count != null && count.isNotEmpty) return count;
      }
      final panel = node['engagementPanelTitleHeaderRenderer'];
      if (panel is Map<String, dynamic>) {
        final title = _readSimpleText(panel['title'])?.toLowerCase() ?? '';
        if (title.contains('comment')) {
          final info = _readSimpleText(panel['contextualInfo']);
          if (info != null && info.isNotEmpty) return info;
        }
      }
      for (final value in node.values) {
        final found = _findTotalCommentsCount(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findTotalCommentsCount(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _findOwnerAvatarUrl(dynamic node) {
    if (node is Map<String, dynamic>) {
      final owner = node['videoOwnerRenderer'];
      if (owner is Map<String, dynamic>) {
        final thumbs = (owner['thumbnail']?['thumbnails'] as List?) ?? const [];
        if (thumbs.isNotEmpty) {
          return thumbs.last['url'] as String?;
        }
      }
      for (final value in node.values) {
        final found = _findOwnerAvatarUrl(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findOwnerAvatarUrl(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _findSubscriberCount(dynamic node) {
    if (node is Map<String, dynamic>) {
      final owner = node['videoOwnerRenderer'];
      if (owner is Map<String, dynamic>) {
        final text = _readSimpleText(owner['subscriberCountText']);
        if (text != null && text.isNotEmpty) return text;
      }
      final subText = _readSimpleText(node['subscriberCountText']);
      if (subText != null && subText.toLowerCase().contains('subscriber')) {
        return subText;
      }
      for (final value in node.values) {
        final found = _findSubscriberCount(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findSubscriberCount(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<({String? description, String? likes, bool isLive, String? channelId})?>
      _fetchVideoMeta(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId).timeout(const Duration(seconds: 6));
      return (
        description: video.description,
        likes: _formatCompactCount(video.engagement.likeCount),
        isLive: video.isLive,
        channelId: video.channelId.value,
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

  Future<CommentsPage> _fetchComments(String videoId) async {
    final innerPage = await _innerTubeCommentsFirstPage(videoId);
    if (innerPage.comments.isNotEmpty) return innerPage;

    try {
      final video = await _yt.videos.get(videoId).timeout(const Duration(seconds: 6));
      final commentsList =
          await _yt.videos.comments.getComments(video).timeout(const Duration(seconds: 8));
      if (commentsList != null && commentsList.isNotEmpty) {
        final items = commentsList.take(20).map((c) {
          return CommentItem(
            id: '${c.author}_${c.publishedTime}',
            author: c.author,
            text: c.text,
            publishedAgo: c.publishedTime,
            likes: _formatCompactCount(c.likeCount) ?? '0',
            replyCount: c.replyCount,
          );
        }).toList();
        return CommentsPage(comments: items);
      }
    } catch (_) {}

    return const CommentsPage();
  }

  Future<CommentsPage> _innerTubeCommentsFirstPage(String videoId) async {
    try {
      final uri = Uri.https('www.youtube.com', '/youtubei/v1/next');
      const headers = {'Content-Type': 'application/json'};
      const clientContext = {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20241114.01.00',
          'hl': 'en',
          'gl': 'US',
        },
      };

      final firstRes = await _http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'context': clientContext,
              'videoId': videoId,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (firstRes.statusCode != 200) return const CommentsPage();

      final token = _findCommentsToken(jsonDecode(firstRes.body));
      if (token == null) return const CommentsPage();
      return fetchMoreComments(token);
    } catch (_) {
      return const CommentsPage();
    }
  }

  Future<CommentsPage> fetchMoreComments(String continuationToken) async {
    try {
      final uri = Uri.https('www.youtube.com', '/youtubei/v1/next');
      final res = await _http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'context': const {
                'client': {
                  'clientName': 'WEB',
                  'clientVersion': '2.20241114.01.00',
                  'hl': 'en',
                  'gl': 'US',
                },
              },
              'continuation': continuationToken,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const CommentsPage();

      final json = jsonDecode(res.body);
      final comments = <CommentItem>[];
      _collectComments(json, comments);
      final nextToken = _findNextContinuationToken(json, continuationToken);
      return CommentsPage(
        comments: comments.take(20).toList(),
        nextToken: nextToken,
      );
    } catch (_) {
      return const CommentsPage();
    }
  }

  String? _findNextContinuationToken(dynamic node, String currentToken) {
    if (node is Map<String, dynamic>) {
      final cir = node['continuationItemRenderer'];
      if (cir is Map<String, dynamic>) {
        final token = cir['continuationEndpoint']?['continuationCommand']
            ?['token'] as String?;
        if (token != null && token.isNotEmpty && token != currentToken) {
          return token;
        }
      }
      for (final value in node.values) {
        final found = _findNextContinuationToken(value, currentToken);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findNextContinuationToken(item, currentToken);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _findCommentsToken(dynamic node) {
    if (node is Map<String, dynamic>) {
      final sectionId = node['sectionIdentifier'] as String?;
      if (sectionId == 'comment-item-section') {
        return _findFirstToken(node);
      }
      final panelId = node['panelIdentifier'] as String?;
      if (panelId == 'engagement-panel-comments-section') {
        return _findFirstToken(node);
      }
      for (final value in node.values) {
        final found = _findCommentsToken(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findCommentsToken(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _findFirstToken(dynamic node) {
    if (node is Map<String, dynamic>) {
      final cmd = node['continuationCommand'];
      if (cmd is Map<String, dynamic>) {
        final token = cmd['token'] as String?;
        if (token != null && token.isNotEmpty) return token;
      }
      for (final value in node.values) {
        final found = _findFirstToken(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findFirstToken(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  void _collectComments(dynamic node, List<CommentItem> out) {
    if (out.length >= 25) return;
    if (node is Map<String, dynamic>) {
      final payload = node['commentEntityPayload'];
      if (payload is Map<String, dynamic>) {
        final props = payload['properties'] as Map<String, dynamic>?;
        final author = payload['author'] as Map<String, dynamic>?;
        final toolbar = payload['toolbar'] as Map<String, dynamic>?;
        final avatarSources =
            (payload['avatar']?['image']?['sources'] as List?) ?? const [];
        final avatarUrl = (author?['avatarThumbnailUrl'] as String?) ??
            (avatarSources.isNotEmpty
                ? avatarSources.last['url'] as String?
                : null);
        final text = props?['content']?['content'] as String?;
        if (text != null && text.isNotEmpty) {
          out.add(
            CommentItem(
              id: (props?['commentId'] as String?) ?? '${out.length}',
              author: (author?['displayName'] as String?) ?? '@viewer',
              text: text,
              publishedAgo: (props?['publishedTime'] as String?) ?? '',
              likes: (toolbar?['likeCountLiked'] as String?) ??
                  (toolbar?['likeCountNotliked'] as String?) ??
                  '0',
              avatarUrl: avatarUrl,
              replyCount:
                  int.tryParse('${toolbar?['replyCount'] ?? '0'}') ?? 0,
            ),
          );
          return;
        }
      }
      final cr = node['commentRenderer'];
      if (cr is Map<String, dynamic>) {
        final text = _readRuns(cr['contentText']);
        final authorThumbs =
            (cr['authorThumbnail']?['thumbnails'] as List?) ?? const [];
        final authorAvatar = authorThumbs.isNotEmpty
            ? authorThumbs.last['url'] as String?
            : null;
        if (text != null && text.isNotEmpty) {
          out.add(
            CommentItem(
              id: (cr['commentId'] as String?) ?? '${out.length}',
              author: _readSimpleText(cr['authorText']) ?? '@viewer',
              text: text,
              publishedAgo: _readSimpleText(cr['publishedTimeText']) ?? '',
              likes: _readSimpleText(cr['voteCount']) ?? '0',
              avatarUrl: authorAvatar,
              replyCount: (cr['replyCount'] as int?) ?? 0,
            ),
          );
          return;
        }
      }
      for (final value in node.values) {
        _collectComments(value, out);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectComments(item, out);
      }
    }
  }

  Future<List<LiveChatMessage>> _innerTubeLiveChat(String videoId) async {
    try {
      const headers = {'Content-Type': 'application/json'};
      const clientContext = {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20241114.01.00',
          'hl': 'en',
          'gl': 'US',
        },
      };

      final nextRes = await _http
          .post(
            Uri.https('www.youtube.com', '/youtubei/v1/next'),
            headers: headers,
            body: jsonEncode({
              'context': clientContext,
              'videoId': videoId,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (nextRes.statusCode != 200) return const [];

      final token = _findLiveChatToken(jsonDecode(nextRes.body));
      if (token == null) return const [];

      final chatRes = await _http
          .post(
            Uri.https('www.youtube.com', '/youtubei/v1/live_chat/get_live_chat'),
            headers: headers,
            body: jsonEncode({
              'context': clientContext,
              'continuation': token,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (chatRes.statusCode != 200) return const [];

      final messages = <LiveChatMessage>[];
      _collectLiveChatMessages(jsonDecode(chatRes.body), messages);
      return messages;
    } catch (_) {
      return const [];
    }
  }

  String? _findLiveChatToken(dynamic node) {
    if (node is Map<String, dynamic>) {
      final lc = node['liveChatRenderer'];
      if (lc is Map<String, dynamic>) {
        final continuations = lc['continuations'] as List?;
        if (continuations != null && continuations.isNotEmpty) {
          final token =
              continuations.first['reloadContinuationData']?['continuation']
                  as String?;
          if (token != null && token.isNotEmpty) return token;
        }
      }
      for (final value in node.values) {
        final found = _findLiveChatToken(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findLiveChatToken(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  void _collectLiveChatMessages(dynamic node, List<LiveChatMessage> out) {
    if (out.length >= 40) return;
    if (node is Map<String, dynamic>) {
      final msg = node['liveChatTextMessageRenderer'];
      if (msg is Map<String, dynamic>) {
        final author = _readSimpleText(msg['authorName']) ?? 'Viewer';
        final text = _readRuns(msg['message']) ?? '';
        final time = _readSimpleText(msg['timestampText']) ?? 'Live';
        if (text.isNotEmpty) {
          out.add(
            LiveChatMessage(
              author: author,
              message: text,
              timestampLabel: time,
            ),
          );
        }
        return;
      }
      for (final value in node.values) {
        _collectLiveChatMessages(value, out);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectLiveChatMessages(item, out);
      }
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

  Future<String?> downloadVideoStream(
    String videoId,
    String qualityLabel,
    void Function(double progress) onProgress,
  ) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final isAudioOnly = qualityLabel.toLowerCase().contains('audio');

    final StreamInfo streamInfo;
    if (isAudioOnly && manifest.audioOnly.isNotEmpty) {
      streamInfo = manifest.audioOnly.withHighestBitrate();
    } else if (manifest.muxed.isNotEmpty) {
      final muxedList = manifest.muxed.sortByVideoQuality();
      final match = muxedList.where((s) =>
          qualityLabel.contains('${s.videoResolution.height}')).firstOrNull;
      streamInfo = match ?? muxedList.last;
    } else if (manifest.audioOnly.isNotEmpty) {
      streamInfo = manifest.audioOnly.withHighestBitrate();
    } else {
      return null;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${docsDir.path}/downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final ext = isAudioOnly ? 'm4a' : 'mp4';
    final file = File('${downloadsDir.path}/$videoId.$ext');
    final sink = file.openWrite();

    try {
      final totalBytes = streamInfo.size.totalBytes;
      var receivedBytes = 0;
      await for (final chunk in _yt.videos.streamsClient.get(streamInfo)) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress((receivedBytes / totalBytes).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
      onProgress(1.0);
      return file.path;
    } finally {
      await sink.close();
    }
  }

  void dispose() {
    _yt.close();
    _http.close();
  }
}
