import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:zenplay/core/data/video_repository.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/services/youtube_service.dart';

class ZenPlayController extends ChangeNotifier {
  ZenPlayController({
    YoutubeService? youtubeService,
    this.enableRemoteFetch = true,
  }) : _youtube = youtubeService ?? YoutubeService() {
    if (enableRemoteFetch) {
      _initializeApp();
      _backgroundRefreshTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => refreshFeedInBackground(),
      );
    } else {
      _feedVideos = List.of(VideoRepository.videos);
    }
  }

  final YoutubeService _youtube;
  final bool enableRemoteFetch;
  Timer? _backgroundRefreshTimer;

  ThemeMode _themeMode = ThemeMode.system;
  int _navIndex = 0;
  String _selectedCategory = 'All';
  int _feedPage = 0;
  int _refreshCycle = 0;

  bool _isAppInitializing = false;
  List<VideoItem> _feedVideos = [];
  List<VideoItem> _searchResults = [];
  List<String> _searchSuggestions = [];
  bool _hasActiveSearch = false;
  bool _isLoadingFeed = false;
  bool _isLoadingMoreFeed = false;
  bool _isLoadingSearch = false;
  bool _isLoadingWatchDetails = false;
  bool _isLoadingMoreComments = false;
  String? _commentsNextToken;

  VideoItem? _activeVideo;
  bool _isWatchExpanded = false;
  YoutubePlayerController? _ytController;
  StreamSubscription<YoutubeVideoState>? _ytStateSub;
  List<String> _availableQualities = const ['Auto'];
  List<SponsorSegment> _activeSponsorSegments = const [];
  final List<LiveChatMessage> _liveChatMessages = [];
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  double _playbackSpeed = 1.0;
  String _selectedQuality = 'Auto';

  bool _sponsorBlockEnabled = true;
  bool _deArrowEnabled = true;
  bool _returnDislikeEnabled = true;
  bool _backgroundPlayEnabled = true;
  bool _autoPlayEnabled = true;
  bool _hideShortsEnabled = true;

  final Set<String> _likedVideoIds = {};
  final Set<String> _dislikedVideoIds = {};
  final Map<String, String> _downloadedQualities = {};
  final Map<String, String> _downloadedFilePaths = {};
  final Map<String, double> _downloadProgress = {};
  final List<String> _watchHistoryIds = [];
  final Map<String, Set<String>> _savedFolders = {
    'Watch Later': {},
    'Music': {},
    'Tech': {},
  };
  final List<String> _recentSearches = ['Latest songs', 'Flutter Material 3', 'Lofi focus'];

  ThemeMode get themeMode => _themeMode;
  int get navIndex => _navIndex;
  String get selectedCategory => _selectedCategory;
  bool get isAppInitializing => _isAppInitializing;
  bool get isLoadingFeed => _isLoadingFeed;
  bool get isLoadingMoreFeed => _isLoadingMoreFeed;
  bool get isLoadingSearch => _isLoadingSearch;
  bool get isLoadingWatchDetails => _isLoadingWatchDetails;
  bool get isLoadingMoreComments => _isLoadingMoreComments;
  bool get hasMoreComments => _commentsNextToken != null;
  VideoItem? get activeVideo => _activeVideo;
  bool get isWatchExpanded => _isWatchExpanded;
  YoutubePlayerController? get youtubeController => _ytController;
  List<String> get availableQualities => List.unmodifiable(_availableQualities);
  List<SponsorSegment> get activeSponsorSegments => _activeSponsorSegments;
  List<LiveChatMessage> get liveChatMessages => List.unmodifiable(_liveChatMessages);
  bool get isPlaying => _isPlaying;
  double get playbackProgress => _playbackProgress;
  double get playbackSpeed => _playbackSpeed;
  String get selectedQuality => _selectedQuality;

  bool get sponsorBlockEnabled => _sponsorBlockEnabled;
  bool get deArrowEnabled => _deArrowEnabled;
  bool get returnDislikeEnabled => _returnDislikeEnabled;
  bool get backgroundPlayEnabled => _backgroundPlayEnabled;
  bool get autoPlayEnabled => _autoPlayEnabled;
  bool get hideShortsEnabled => _hideShortsEnabled;

  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  List<String> get searchSuggestions => List.unmodifiable(_searchSuggestions);
  bool get hasActiveSearch => _hasActiveSearch;

  List<VideoItem> get feedVideos {
    if (!enableRemoteFetch && _selectedCategory != 'All') {
      return VideoRepository.videos
          .where((v) => v.category == _selectedCategory)
          .toList();
    }
    return _feedVideos;
  }

  List<VideoItem> get _allKnownVideos {
    final byId = <String, VideoItem>{};
    for (final v in VideoRepository.videos) {
      byId[v.id] = v;
    }
    for (final v in _feedVideos) {
      byId[v.id] = v;
    }
    for (final v in _searchResults) {
      byId[v.id] = v;
    }
    if (_activeVideo != null) {
      byId[_activeVideo!.id] = _activeVideo!;
    }
    return byId.values.toList();
  }

  List<VideoItem> get downloadedVideos => _allKnownVideos
      .where((v) => _downloadedQualities.containsKey(v.id))
      .toList();

  List<VideoItem> get historyVideos {
    final map = {for (final v in _allKnownVideos) v.id: v};
    return _watchHistoryIds
        .take(10)
        .map((id) => map[id])
        .whereType<VideoItem>()
        .toList();
  }

  List<VideoItem> upNextFor(VideoItem current) {
    final source = _feedVideos.isNotEmpty ? _feedVideos : _allKnownVideos;
    return source.where((v) => v.id != current.id).toList();
  }

  List<VideoItem> searchVideos(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    if (_hasActiveSearch) return _searchResults;
    return _allKnownVideos.where((v) {
      return v.title.toLowerCase().contains(q) ||
          v.channel.name.toLowerCase().contains(q) ||
          v.category.toLowerCase().contains(q);
    }).toList();
  }

  List<String> get folderNames => List.unmodifiable(_savedFolders.keys);

  List<VideoItem> videosInFolder(String folder) {
    final ids = _savedFolders[folder] ?? const <String>{};
    final map = {for (final v in _allKnownVideos) v.id: v};
    return ids.map((id) => map[id]).whereType<VideoItem>().toList();
  }

  int countInFolder(String folder) => _savedFolders[folder]?.length ?? 0;

  bool isSavedInFolder(String folder, String videoId) =>
      _savedFolders[folder]?.contains(videoId) ?? false;

  bool isSaved(String videoId) =>
      _savedFolders.values.any((ids) => ids.contains(videoId));
  bool isLiked(String videoId) => _likedVideoIds.contains(videoId);
  bool isDisliked(String videoId) => _dislikedVideoIds.contains(videoId);
  bool isDownloaded(String videoId) => _downloadedQualities.containsKey(videoId);
  bool isDownloading(String videoId) => _downloadProgress.containsKey(videoId);
  double? downloadProgressFor(String videoId) => _downloadProgress[videoId];
  String? downloadedQualityFor(String videoId) => _downloadedQualities[videoId];
  String? downloadedFilePathFor(String videoId) => _downloadedFilePaths[videoId];

  Future<void> _initializeApp() async {
    _isAppInitializing = true;
    notifyListeners();
    try {
      await loadFeed();
      if (_feedVideos.isEmpty) {
        _feedVideos = List.of(VideoRepository.videos);
      }
    } finally {
      _isAppInitializing = false;
      notifyListeners();
    }
  }

  Future<void> loadFeed({String? category, bool isRefresh = false}) async {
    final target = category ?? _selectedCategory;
    if (!enableRemoteFetch) return;
    if (isRefresh) {
      _refreshCycle += 1;
      _feedPage = _refreshCycle;
    } else {
      _feedPage = _refreshCycle;
    }
    _isLoadingFeed = true;
    notifyListeners();
    try {
      final remote = await _youtube.fetchFeed(target, page: _feedPage);
      if (remote.isNotEmpty) {
        final shuffled = List.of(remote)..shuffle();
        _feedVideos = shuffled;
      } else if (_feedVideos.isEmpty) {
        _feedVideos = List.of(VideoRepository.videos);
      }
    } catch (_) {
      if (_feedVideos.isEmpty) {
        _feedVideos = List.of(VideoRepository.videos);
      }
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  Future<void> refreshFeedInBackground() async {
    if (!enableRemoteFetch || _isLoadingFeed || _isLoadingMoreFeed) return;
    try {
      _refreshCycle += 1;
      final remote = await _youtube.fetchFeed(
        _selectedCategory,
        page: _refreshCycle,
      );
      if (remote.isEmpty) return;
      final existingIds = _feedVideos.map((v) => v.id).toSet();
      final fresh = remote.where((v) => !existingIds.contains(v.id)).toList();
      if (fresh.isNotEmpty) {
        _feedVideos = [...fresh, ..._feedVideos];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadMoreFeed() async {
    if (!enableRemoteFetch || _isLoadingFeed || _isLoadingMoreFeed) return;
    _isLoadingMoreFeed = true;
    notifyListeners();
    try {
      _feedPage += 1;
      final more = await _youtube.fetchFeed(_selectedCategory, page: _feedPage);
      final existingIds = _feedVideos.map((v) => v.id).toSet();
      final unique = more.where((v) => !existingIds.contains(v.id)).toList();
      if (unique.isNotEmpty) {
        _feedVideos = [..._feedVideos, ...unique];
      }
    } catch (_) {
    } finally {
      _isLoadingMoreFeed = false;
      notifyListeners();
    }
  }

  Future<String?> fetchChannelSubscribers(String channelId) {
    if (!enableRemoteFetch) return Future.value(null);
    return _youtube.fetchChannelSubscribers(channelId);
  }

  Future<List<VideoItem>> fetchChannelUploads(String channelId) async {
    if (!enableRemoteFetch) {
      return VideoRepository.videos
          .where((v) => v.channel.id == channelId)
          .toList();
    }
    try {
      final uploads = await _youtube.fetchChannelVideos(channelId);
      if (uploads.isNotEmpty) return uploads;
    } catch (_) {}
    return _allKnownVideos.where((v) => v.channel.id == channelId).toList();
  }

  Future<void> updateSearchSuggestions(String query) async {
    _hasActiveSearch = false;
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      _searchSuggestions = [];
      notifyListeners();
      return;
    }
    if (!enableRemoteFetch) return;
    final suggestions = await _youtube.fetchSearchSuggestions(cleaned);
    _searchSuggestions = suggestions;
    notifyListeners();
  }

  Future<void> performSearch(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      _hasActiveSearch = false;
      _searchResults = [];
      _searchSuggestions = [];
      notifyListeners();
      return;
    }
    addSearchQuery(cleaned);
    if (!enableRemoteFetch) return;
    _hasActiveSearch = true;
    _isLoadingSearch = true;
    notifyListeners();
    try {
      _searchResults = await _youtube.searchVideos(cleaned);
    } catch (_) {
      _searchResults = [];
    } finally {
      _isLoadingSearch = false;
      notifyListeners();
    }
  }

  void setNavIndex(int index) {
    if (_navIndex == index) return;
    _navIndex = index;
    notifyListeners();
  }

  void setCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
    loadFeed(category: category);
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void expandWatch() {
    if (_activeVideo == null || _isWatchExpanded) return;
    _isWatchExpanded = true;
    notifyListeners();
  }

  void minimizeWatch() {
    if (!_isWatchExpanded) return;
    _isWatchExpanded = false;
    notifyListeners();
  }

  Future<void> playVideo(VideoItem video) async {
    _activeVideo = video;
    _isWatchExpanded = true;
    _availableQualities = const ['Auto'];
    _activeSponsorSegments = const [];
    _commentsNextToken = null;
    _isLoadingMoreComments = false;
    _seedLiveChat(video);
    _isPlaying = true;
    _playbackProgress = 0.0;
    _watchHistoryIds.remove(video.id);
    _watchHistoryIds.insert(0, video.id);
    if (_watchHistoryIds.length > 10) {
      _watchHistoryIds.removeRange(10, _watchHistoryIds.length);
    }

    if (enableRemoteFetch) {
      _ensureYoutubeController(video);
    }

    if (!enableRemoteFetch) {
      notifyListeners();
      return;
    }

    _isLoadingWatchDetails = true;
    notifyListeners();

    try {
      final details = await _youtube.resolvePlaybackDetails(
        video.id,
        channelId: video.channel.id,
        isLiveHint: video.isLive,
      );
      if (_activeVideo?.id != video.id) return;
      _availableQualities = details.availableQualities;
      _activeSponsorSegments = details.sponsorSegments;
      _commentsNextToken = details.commentsNextToken;
      if (details.liveChatMessages.isNotEmpty) {
        _liveChatMessages
          ..clear()
          ..addAll(details.liveChatMessages);
      }
      _activeVideo = video.copyWith(
        channel: (details.subscriberCount != null ||
                details.channelAvatarUrl != null)
            ? video.channel.copyWith(
                subscriberCount: details.subscriberCount,
                avatarUrl: details.channelAvatarUrl,
              )
            : null,
        description: details.description ?? video.description,
        likesCount: details.likesCount ?? video.likesCount,
        dislikesCount: details.dislikesCount ?? video.dislikesCount,
        totalCommentsCount: details.totalCommentsCount ?? video.totalCommentsCount,
        isLive: details.isLive || video.isLive,
        hasSponsorBlock: details.sponsorSegments.isNotEmpty || video.hasSponsorBlock,
        comments: details.comments.isNotEmpty ? details.comments : video.comments,
      );
    } catch (_) {
    } finally {
      _isLoadingWatchDetails = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreComments() async {
    final token = _commentsNextToken;
    final video = _activeVideo;
    if (token == null || video == null || _isLoadingMoreComments) return;

    _isLoadingMoreComments = true;
    notifyListeners();

    try {
      final page = await _youtube.fetchMoreComments(token);
      if (_activeVideo?.id != video.id) return;
      _commentsNextToken = page.nextToken;
      if (page.comments.isNotEmpty) {
        _activeVideo = _activeVideo!.copyWith(
          comments: [..._activeVideo!.comments, ...page.comments],
        );
      }
    } catch (_) {
    } finally {
      _isLoadingMoreComments = false;
      notifyListeners();
    }
  }

  void clearHistory() {
    _watchHistoryIds.clear();
    notifyListeners();
  }

  void clearSearchHistory() {
    _recentSearches.clear();
    notifyListeners();
  }

  void clearDownloads() {
    for (final path in _downloadedFilePaths.values) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
    _downloadedQualities.clear();
    _downloadedFilePaths.clear();
    _downloadProgress.clear();
    notifyListeners();
  }

  void _seedLiveChat(VideoItem video) {
    _liveChatMessages
      ..clear()
      ..addAll([
        LiveChatMessage(
          author: video.channel.name,
          message: 'Welcome to the live chat!',
          timestampLabel: 'Now',
        ),
        const LiveChatMessage(
          author: '@zen_viewer',
          message: 'Clean Material 3 player looks super smooth.',
          timestampLabel: 'Just now',
        ),
      ]);
  }

  void sendLiveChatMessage(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    _liveChatMessages.add(
      LiveChatMessage(
        author: 'You',
        message: cleaned,
        timestampLabel: 'Now',
      ),
    );
    notifyListeners();
  }

  void _ensureYoutubeController(VideoItem video) {
    if (_ytController == null) {
      final next = YoutubePlayerController.fromVideoId(
        videoId: video.id,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          mute: false,
        ),
      );
      _ytStateSub?.cancel();
      _ytStateSub = next.videoStateStream.listen((state) {
        final active = _activeVideo;
        if (active == null) return;
        final posSec = state.position.inMilliseconds / 1000.0;
        if (active.durationSeconds > 0) {
          _playbackProgress = (posSec / active.durationSeconds).clamp(0.0, 1.0);
          notifyListeners();
        }
        if (_sponsorBlockEnabled) {
          for (final seg in _activeSponsorSegments) {
            if (posSec >= seg.startSeconds && posSec < seg.endSeconds - 0.5) {
              next.seekTo(seconds: seg.endSeconds, allowSeekAhead: true);
              break;
            }
          }
        }
      });
      _ytController = next;
      next.webViewController.runJavaScript(
        "Object.defineProperty(document,'hidden',{get:()=>false});"
        "Object.defineProperty(document,'visibilityState',{get:()=>'visible'});",
      );
    } else {
      _ytController!.loadVideoById(videoId: video.id);
    }
    _ytController?.setPlaybackRate(_playbackSpeed);
  }

  void togglePlayPause() {
    if (_activeVideo == null) return;
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      _ytController?.playVideo();
    } else {
      _ytController?.pauseVideo();
    }
    notifyListeners();
  }

  void seekTo(double progress) {
    _playbackProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  void closeMiniPlayer() {
    _ytStateSub?.cancel();
    _ytStateSub = null;
    _ytController?.close();
    _ytController = null;
    _activeVideo = null;
    _isWatchExpanded = false;
    _activeSponsorSegments = const [];
    _isPlaying = false;
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    _ytController?.setPlaybackRate(speed);
    notifyListeners();
  }

  void setQuality(String quality) {
    _selectedQuality = quality;
    notifyListeners();
  }

  void createFolder(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty || _savedFolders.containsKey(cleaned)) return;
    _savedFolders[cleaned] = {};
    notifyListeners();
  }

  void toggleVideoInFolder(String folder, String videoId) {
    final set = _savedFolders.putIfAbsent(folder, () => {});
    if (set.contains(videoId)) {
      set.remove(videoId);
    } else {
      set.add(videoId);
    }
    notifyListeners();
  }

  void toggleWatchLater(String videoId) {
    toggleVideoInFolder('Watch Later', videoId);
  }

  void toggleLike(String videoId) {
    if (_likedVideoIds.contains(videoId)) {
      _likedVideoIds.remove(videoId);
    } else {
      _likedVideoIds.add(videoId);
      _dislikedVideoIds.remove(videoId);
    }
    notifyListeners();
  }

  void toggleDislike(String videoId) {
    if (_dislikedVideoIds.contains(videoId)) {
      _dislikedVideoIds.remove(videoId);
    } else {
      _dislikedVideoIds.add(videoId);
      _likedVideoIds.remove(videoId);
    }
    notifyListeners();
  }

  Future<void> startDownload(VideoItem video, String quality) async {
    _downloadedQualities[video.id] = quality;
    _downloadProgress[video.id] = 0.0;
    notifyListeners();

    if (!enableRemoteFetch) {
      _downloadProgress.remove(video.id);
      notifyListeners();
      return;
    }

    try {
      final path = await _youtube.downloadVideoStream(
        video.id,
        quality,
        (progress) {
          _downloadProgress[video.id] = progress;
          notifyListeners();
        },
      );
      if (path != null) {
        _downloadedFilePaths[video.id] = path;
      }
    } catch (_) {
      _downloadedQualities.remove(video.id);
    } finally {
      _downloadProgress.remove(video.id);
      notifyListeners();
    }
  }

  void removeDownload(String videoId) {
    final path = _downloadedFilePaths.remove(videoId);
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
    _downloadedQualities.remove(videoId);
    _downloadProgress.remove(videoId);
    notifyListeners();
  }

  void toggleDownload(String videoId) {
    if (_downloadedQualities.containsKey(videoId)) {
      removeDownload(videoId);
    } else {
      final video = _allKnownVideos.where((v) => v.id == videoId).firstOrNull;
      if (video != null) {
        startDownload(video, _selectedQuality);
      }
    }
  }

  void addSearchQuery(String query) {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return;
    _recentSearches.remove(cleaned);
    _recentSearches.insert(0, cleaned);
    if (_recentSearches.length > 8) {
      _recentSearches.removeLast();
    }
    notifyListeners();
  }

  void setSponsorBlock(bool value) {
    _sponsorBlockEnabled = value;
    notifyListeners();
  }

  void setDeArrow(bool value) {
    _deArrowEnabled = value;
    notifyListeners();
  }

  void setReturnDislike(bool value) {
    _returnDislikeEnabled = value;
    notifyListeners();
  }

  void setBackgroundPlay(bool value) {
    _backgroundPlayEnabled = value;
    notifyListeners();
  }

  void setAutoPlay(bool value) {
    _autoPlayEnabled = value;
    notifyListeners();
  }

  void setHideShorts(bool value) {
    _hideShortsEnabled = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _backgroundRefreshTimer?.cancel();
    _ytStateSub?.cancel();
    _ytController?.close();
    _youtube.dispose();
    super.dispose();
  }
}
