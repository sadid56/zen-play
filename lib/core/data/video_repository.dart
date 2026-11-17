import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/services/youtube_service.dart';
export 'package:zenplay/core/services/youtube_service.dart'
    show
        ChannelProfileData,
        CommentsPage,
        PlaybackDetails,
        StreamResolutionResult,
        StreamTrackOption;

class ApiEndpoints {
  const ApiEndpoints({
    this.youtubeSearchUrl = 'https://www.youtube.com/youtubei/v1/search',
    this.youtubeNextUrl = 'https://www.youtube.com/youtubei/v1/next',
    this.youtubeBrowseUrl = 'https://www.youtube.com/youtubei/v1/browse',
    this.youtubeLiveChatUrl =
        'https://www.youtube.com/youtubei/v1/live_chat/get_live_chat',
    this.youtubeSuggestUrl = 'https://suggestqueries.google.com/complete/search',
    this.sponsorBlockUrl = 'https://sponsor.ajay.app/api/skipSegments',
    this.returnDislikeUrl = 'https://returnyoutubedislikeapi.com/votes',
  });

  final String youtubeSearchUrl;
  final String youtubeNextUrl;
  final String youtubeBrowseUrl;
  final String youtubeLiveChatUrl;
  final String youtubeSuggestUrl;
  final String sponsorBlockUrl;
  final String returnDislikeUrl;
}

abstract interface class VideoDataRepository {
  Future<List<VideoItem>> fetchFeed(String category, {int page = 0});
  Future<List<String>> fetchSearchSuggestions(String query);
  Future<List<VideoItem>> searchVideos(String query, {String category = 'All'});
  Future<VideoItem?> fetchVideoById(String videoId);
  Future<ChannelProfileData> fetchChannelProfile(
    String channelId,
    String channelName,
  );
  Future<String?> fetchChannelSubscribers(String channelId);
  Future<StreamResolutionResult> fetchStreamsFast(
    String videoId, {
    bool isLiveHint = false,
  });
  Future<void> prefetchStreams(Iterable<String> videoIds, {int maxCount = 3});
  Future<PlaybackDetails> resolvePlaybackDetails(
    String videoId, {
    String? channelId,
    bool isLiveHint = false,
  });
  Future<CommentsPage> fetchMoreComments(String continuationToken);
  Future<List<CommentItem>> fetchCommentReplies(String repliesToken);
  Future<String?> downloadVideoStream(
    String videoId,
    String qualityLabel,
    void Function(double progress) onProgress,
  );
  String? extractVideoId(String input);
  void dispose();
}

class YoutubeDataRepository implements VideoDataRepository {
  YoutubeDataRepository({
    ApiEndpoints endpoints = const ApiEndpoints(),
    YoutubeService? service,
  }) : _service = service ?? YoutubeService(endpoints: endpoints);

  final YoutubeService _service;

  @override
  Future<List<VideoItem>> fetchFeed(String category, {int page = 0}) =>
      _service.fetchFeed(category, page: page);

  @override
  Future<List<String>> fetchSearchSuggestions(String query) =>
      _service.fetchSearchSuggestions(query);

  @override
  Future<List<VideoItem>> searchVideos(String query, {String category = 'All'}) =>
      _service.searchVideos(query, category: category);

  @override
  Future<VideoItem?> fetchVideoById(String videoId) =>
      _service.fetchVideoById(videoId);

  @override
  Future<ChannelProfileData> fetchChannelProfile(
    String channelId,
    String channelName,
  ) =>
      _service.fetchChannelProfile(channelId, channelName);

  @override
  Future<String?> fetchChannelSubscribers(String channelId) =>
      _service.fetchChannelSubscribers(channelId);

  @override
  Future<StreamResolutionResult> fetchStreamsFast(
    String videoId, {
    bool isLiveHint = false,
  }) =>
      _service.fetchStreamsFast(videoId, isLiveHint: isLiveHint);

  @override
  Future<void> prefetchStreams(Iterable<String> videoIds, {int maxCount = 3}) =>
      _service.prefetchStreams(videoIds, maxCount: maxCount);

  @override
  Future<PlaybackDetails> resolvePlaybackDetails(
    String videoId, {
    String? channelId,
    bool isLiveHint = false,
  }) =>
      _service.resolvePlaybackDetails(
        videoId,
        channelId: channelId,
        isLiveHint: isLiveHint,
      );

  @override
  Future<CommentsPage> fetchMoreComments(String continuationToken) =>
      _service.fetchMoreComments(continuationToken);

  @override
  Future<List<CommentItem>> fetchCommentReplies(String repliesToken) =>
      _service.fetchCommentReplies(repliesToken);

  @override
  Future<String?> downloadVideoStream(
    String videoId,
    String qualityLabel,
    void Function(double progress) onProgress,
  ) =>
      _service.downloadVideoStream(videoId, qualityLabel, onProgress);

  @override
  String? extractVideoId(String input) => YoutubeService.extractVideoId(input);

  @override
  void dispose() => _service.dispose();
}

class VideoRepository {
  static const List<String> categories = [
    'All',
    'Live',
    'Tech',
    'Music',
    'Design',
    'Gaming',
    'Podcasts',
  ];

  static const List<VideoItem> videos = [];
}
