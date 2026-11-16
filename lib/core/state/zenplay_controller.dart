import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:zenplay/core/data/video_repository.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';

class ZenPlayController extends ChangeNotifier with WidgetsBindingObserver {
  ZenPlayController({
    VideoDataRepository? repository,
    this.enableRemoteFetch = true,
  }) : _repository = repository ?? YoutubeDataRepository() {
    WidgetsBinding.instance.addObserver(this);
    if (enableRemoteFetch) {
      _initializeApp();
      _backgroundRefreshTimer = Timer.periodic(
        const Duration(minutes: 10),
        (_) => refreshFeedInBackground(),
      );
    } else {
      _feedVideos = List.of(VideoRepository.videos);
    }
  }

  final VideoDataRepository _repository;
  final bool enableRemoteFetch;
  Timer? _backgroundRefreshTimer;
  Timer? _sleepTimer;
  int? _sleepTimerMinutes;
  final Map<String, VideoItem> _persistedVideos = {};

  ThemeMode _themeMode = ThemeMode.system;
  int _navIndex = 0;
  String _selectedCategory = 'All';
  int _feedPage = 0;
  int _refreshCycle = 0;

  bool _isAppInitializing = false;
  List<VideoItem> _feedVideos = [];
  List<VideoItem> _relatedVideos = [];
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
  VideoPlayerController? _videoController;
  VideoPlayerController? _audioController;
  Map<String, StreamTrackOption> _qualityStreams = const {};
  List<String> _availableQualities = const ['Auto'];
  List<SponsorSegment> _activeSponsorSegments = const [];
  final List<LiveChatMessage> _liveChatMessages = [];
  bool _isPlaying = false;
  bool _isLooping = false;
  bool _isMuted = false;
  int _volume = 100;
  final ValueNotifier<double> playbackProgressNotifier = ValueNotifier<double>(0.0);
  double _playbackSpeed = 1.0;
  String _selectedQuality = 'Auto';
  bool _handledEndForCurrent = false;

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
  final List<VideoItem> _playQueue = [];
  final List<String> _interestQueries = [];
  final Map<String, Set<String>> _savedFolders = {};
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
  VideoPlayerController? get videoController => _videoController;
  bool get isLooping => _isLooping;
  bool get isMuted => _isMuted;
  int get volume => _volume;
  List<String> get availableQualities => List.unmodifiable(_availableQualities);
  List<SponsorSegment> get activeSponsorSegments => _activeSponsorSegments;
  List<LiveChatMessage> get liveChatMessages => List.unmodifiable(_liveChatMessages);
  bool get isPlaying => _isPlaying;
  double get playbackProgress => playbackProgressNotifier.value;
  double get playbackSpeed => _playbackSpeed;
  String get selectedQuality => _selectedQuality;

  bool get sponsorBlockEnabled => _sponsorBlockEnabled;
  bool get deArrowEnabled => _deArrowEnabled;
  bool get returnDislikeEnabled => _returnDislikeEnabled;
  bool get backgroundPlayEnabled => _backgroundPlayEnabled;
  bool get autoPlayEnabled => _autoPlayEnabled;
  bool get hideShortsEnabled => _hideShortsEnabled;
  int? get sleepTimerMinutes => _sleepTimerMinutes;

  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  List<VideoItem> get playQueue => List.unmodifiable(_playQueue);
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
    for (final v in _persistedVideos.values) {
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
    final queued = _playQueue.where((v) => v.id != current.id).toList();
    final related = _relatedVideos.isNotEmpty
        ? _relatedVideos.where((v) => v.id != current.id).toList()
        : (_feedVideos.isNotEmpty ? _feedVideos : _allKnownVideos)
            .where((v) => v.id != current.id)
            .toList();
    if (queued.isEmpty) return related;
    final queuedIds = queued.map((v) => v.id).toSet();
    return [...queued, ...related.where((v) => !queuedIds.contains(v.id))];
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
      await _loadPersistedState();
      await loadFeed();
      if (_feedVideos.isEmpty) {
        _feedVideos = List.of(VideoRepository.videos);
      }
    } finally {
      _isAppInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIdx = prefs.getInt('themeMode');
      if (themeIdx != null && themeIdx >= 0 && themeIdx < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeIdx];
      }
      _selectedQuality = prefs.getString('selectedQuality') ?? _selectedQuality;
      _playbackSpeed = prefs.getDouble('playbackSpeed') ?? _playbackSpeed;
      _backgroundPlayEnabled =
          prefs.getBool('backgroundPlayEnabled') ?? _backgroundPlayEnabled;
      _autoPlayEnabled = prefs.getBool('autoPlayEnabled') ?? _autoPlayEnabled;
      _sponsorBlockEnabled =
          prefs.getBool('sponsorBlockEnabled') ?? _sponsorBlockEnabled;
      _returnDislikeEnabled =
          prefs.getBool('returnDislikeEnabled') ?? _returnDislikeEnabled;

      final searches = prefs.getStringList('recentSearches');
      if (searches != null) {
        _recentSearches
          ..clear()
          ..addAll(searches);
      }

      final history = prefs.getStringList('watchHistoryIds');
      if (history != null) {
        _watchHistoryIds
          ..clear()
          ..addAll(history.take(10));
      }

      final foldersRaw = prefs.getString('savedFolders');
      if (foldersRaw != null) {
        final decoded = jsonDecode(foldersRaw) as Map<String, dynamic>;
        _savedFolders.clear();
        for (final entry in decoded.entries) {
          final list = (entry.value as List).whereType<String>().toSet();
          _savedFolders[entry.key] = list;
        }
      }

      final downloadsRaw = prefs.getString('downloadedQualities');
      if (downloadsRaw != null) {
        final decoded = jsonDecode(downloadsRaw) as Map<String, dynamic>;
        _downloadedQualities
          ..clear()
          ..addAll(decoded.map((k, v) => MapEntry(k, '$v')));
      }

      final pathsRaw = prefs.getString('downloadedFilePaths');
      if (pathsRaw != null) {
        final decoded = jsonDecode(pathsRaw) as Map<String, dynamic>;
        _downloadedFilePaths
          ..clear()
          ..addAll(decoded.map((k, v) => MapEntry(k, '$v')));
      }

      final videosRaw = prefs.getString('persistedVideos');
      if (videosRaw != null) {
        final decoded = jsonDecode(videosRaw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            _persistedVideos[entry.key] =
                VideoItem.fromJson(entry.value as Map<String, dynamic>);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _savePersistedState() async {
    if (!enableRemoteFetch) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', _themeMode.index);
      await prefs.setString('selectedQuality', _selectedQuality);
      await prefs.setDouble('playbackSpeed', _playbackSpeed);
      await prefs.setBool('backgroundPlayEnabled', _backgroundPlayEnabled);
      await prefs.setBool('autoPlayEnabled', _autoPlayEnabled);
      await prefs.setBool('sponsorBlockEnabled', _sponsorBlockEnabled);
      await prefs.setBool('returnDislikeEnabled', _returnDislikeEnabled);
      await prefs.setStringList('recentSearches', _recentSearches);
      await prefs.setStringList('watchHistoryIds', _watchHistoryIds);

      final foldersMap = {
        for (final e in _savedFolders.entries) e.key: e.value.toList(),
      };
      await prefs.setString('savedFolders', jsonEncode(foldersMap));
      await prefs.setString(
        'downloadedQualities',
        jsonEncode(_downloadedQualities),
      );
      await prefs.setString(
        'downloadedFilePaths',
        jsonEncode(_downloadedFilePaths),
      );

      final neededIds = <String>{
        ..._watchHistoryIds,
        ..._downloadedQualities.keys,
        for (final ids in _savedFolders.values) ...ids,
      };
      final allMap = {for (final v in _allKnownVideos) v.id: v};
      final toStore = <String, dynamic>{};
      for (final id in neededIds) {
        final v = allMap[id];
        if (v != null) {
          _persistedVideos[id] = v;
          toStore[id] = v.toJson();
        }
      }
      await prefs.setString('persistedVideos', jsonEncode(toStore));
    } catch (_) {}
  }

  Future<VideoItem?> openVideoUrlIfValid(String input) async {
    final videoId = _repository.extractVideoId(input);
    if (videoId == null) return null;
    if (!enableRemoteFetch) return null;
    return _repository.fetchVideoById(videoId);
  }

  void setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerMinutes = minutes;
    if (minutes != null && minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        _sleepTimerMinutes = null;
        if (_isPlaying) {
          _isPlaying = false;
          _videoController?.pause();
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void addToQueue(VideoItem video) {
    if (_playQueue.any((v) => v.id == video.id)) return;
    _playQueue.add(video);
    notifyListeners();
  }

  void playNextVideo() {
    if (_playQueue.isNotEmpty) {
      final next = _playQueue.removeAt(0);
      playVideo(next);
      return;
    }
    final current = _activeVideo;
    if (current == null) return;
    final nextList = upNextFor(current);
    if (nextList.isNotEmpty) {
      playVideo(nextList.first);
    }
  }

  String exportBackupJson() {
    final neededIds = <String>{
      for (final ids in _savedFolders.values) ...ids,
    };
    final allMap = {for (final v in _allKnownVideos) v.id: v};
    final videos = <String, dynamic>{};
    for (final id in neededIds) {
      final v = allMap[id];
      if (v != null) videos[id] = v.toJson();
    }
    return jsonEncode({
      'themeMode': _themeMode.index,
      'selectedQuality': _selectedQuality,
      'playbackSpeed': _playbackSpeed,
      'backgroundPlayEnabled': _backgroundPlayEnabled,
      'autoPlayEnabled': _autoPlayEnabled,
      'sponsorBlockEnabled': _sponsorBlockEnabled,
      'returnDislikeEnabled': _returnDislikeEnabled,
      'savedFolders': {
        for (final e in _savedFolders.entries) e.key: e.value.toList(),
      },
      'videos': videos,
    });
  }

  bool importBackupJson(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final themeIdx = data['themeMode'] as int?;
      if (themeIdx != null && themeIdx >= 0 && themeIdx < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeIdx];
      }
      _selectedQuality = (data['selectedQuality'] as String?) ?? _selectedQuality;
      _playbackSpeed = (data['playbackSpeed'] as num?)?.toDouble() ?? _playbackSpeed;
      _backgroundPlayEnabled =
          (data['backgroundPlayEnabled'] as bool?) ?? _backgroundPlayEnabled;
      _autoPlayEnabled = (data['autoPlayEnabled'] as bool?) ?? _autoPlayEnabled;
      _sponsorBlockEnabled =
          (data['sponsorBlockEnabled'] as bool?) ?? _sponsorBlockEnabled;
      _returnDislikeEnabled =
          (data['returnDislikeEnabled'] as bool?) ?? _returnDislikeEnabled;

      final folders = data['savedFolders'] as Map<String, dynamic>?;
      if (folders != null) {
        _savedFolders.clear();
        for (final e in folders.entries) {
          _savedFolders[e.key] = (e.value as List).whereType<String>().toSet();
        }
      }
      final videos = data['videos'] as Map<String, dynamic>?;
      if (videos != null) {
        for (final e in videos.entries) {
          if (e.value is Map<String, dynamic>) {
            _persistedVideos[e.key] =
                VideoItem.fromJson(e.value as Map<String, dynamic>);
          }
        }
      }
      _savePersistedState();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
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
      final remote = await _fetchPersonalizedOrCategory(target, _feedPage);
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

  Future<List<VideoItem>> _fetchPersonalizedOrCategory(
    String category,
    int page,
  ) async {
    if (category == 'All' && _interestQueries.isNotEmpty) {
      final query = _interestQueries[page % _interestQueries.length];
      final results = await _repository.searchVideos(query, category: 'All');
      if (results.isNotEmpty) return results;
    }
    return _repository.fetchFeed(category, page: page);
  }

  void _recordInterest(String query) {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return;
    _interestQueries.remove(cleaned);
    _interestQueries.insert(0, cleaned);
    if (_interestQueries.length > 12) {
      _interestQueries.removeLast();
    }
  }

  Future<void> refreshFeedInBackground() async {
    if (!enableRemoteFetch || _isLoadingFeed || _isLoadingMoreFeed) return;
    try {
      _refreshCycle += 1;
      final remote = await _fetchPersonalizedOrCategory(
        _selectedCategory,
        _refreshCycle,
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
      final more = await _fetchPersonalizedOrCategory(
        _selectedCategory,
        _feedPage,
      );
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

  Future<ChannelProfileData> fetchChannelProfile(ChannelInfo channel) async {
    if (!enableRemoteFetch) {
      return ChannelProfileData(
        subscriberCount: channel.subscriberCount,
        avatarUrl: channel.avatarUrl,
        uploads: VideoRepository.videos
            .where((v) => v.channel.id == channel.id)
            .toList(),
      );
    }
    return _repository.fetchChannelProfile(channel.id, channel.name);
  }

  Future<String?> fetchChannelSubscribers(String channelId) {
    if (!enableRemoteFetch) return Future.value(null);
    return _repository.fetchChannelSubscribers(channelId);
  }

  Future<List<VideoItem>> fetchChannelUploads(String channelId) async {
    if (!enableRemoteFetch) {
      return VideoRepository.videos
          .where((v) => v.channel.id == channelId)
          .toList();
    }
    try {
      final profile = await _repository.fetchChannelProfile(channelId, '');
      if (profile.uploads.isNotEmpty) return profile.uploads;
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
    final suggestions = await _repository.fetchSearchSuggestions(cleaned);
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
      _searchResults = await _repository.searchVideos(cleaned);
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
    _savePersistedState();
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
    _relatedVideos = [];
    _qualityStreams = const {};
    _availableQualities = const ['Auto'];
    _activeSponsorSegments = const [];
    _commentsNextToken = null;
    _isLoadingMoreComments = false;
    _handledEndForCurrent = false;
    _seedLiveChat(video);
    _isPlaying = true;
    playbackProgressNotifier.value = 0.0;
    _recordInterest(video.channel.name);
    final words = video.title
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .take(3)
        .join(' ');
    if (words.isNotEmpty) _recordInterest(words);
    _watchHistoryIds.remove(video.id);
    _watchHistoryIds.insert(0, video.id);
    if (_watchHistoryIds.length > 10) {
      _watchHistoryIds.removeRange(10, _watchHistoryIds.length);
    }
    _persistedVideos[video.id] = video;
    _savePersistedState();

    final localPath = _downloadedFilePaths[video.id];
    if (localPath != null && File(localPath).existsSync()) {
      await _initVideoController(filePath: localPath);
    } else {
      await _disposeVideoController();
    }

    if (!enableRemoteFetch) {
      notifyListeners();
      return;
    }

    _isLoadingWatchDetails = true;
    notifyListeners();

    try {
      final details = await _repository.resolvePlaybackDetails(
        video.id,
        channelId: video.channel.id,
        isLiveHint: video.isLive,
      );
      if (_activeVideo?.id != video.id) return;
      _availableQualities = details.availableQualities;
      _qualityStreams = details.qualityStreams;
      _activeSponsorSegments = details.sponsorSegments;
      _commentsNextToken = details.commentsNextToken;
      _relatedVideos = details.relatedVideos;
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

      if (_videoController == null) {
        final chosenTrack = _qualityStreams[_selectedQuality] ??
            _qualityStreams['Auto'] ??
            (details.streamUrl != null
                ? StreamTrackOption(videoUrl: details.streamUrl!)
                : null);
        if (chosenTrack != null && chosenTrack.videoUrl.isNotEmpty) {
          await _initVideoController(
            networkUrl: chosenTrack.videoUrl,
            audioUrl: chosenTrack.audioUrl,
          );
        }
      }
    } catch (_) {
    } finally {
      _isLoadingWatchDetails = false;
      notifyListeners();
    }
  }

  final Set<String> _loadingRepliesIds = {};
  final Set<String> _expandedRepliesIds = {};

  bool isRepliesExpanded(String commentId) =>
      _expandedRepliesIds.contains(commentId);
  bool isLoadingReplies(String commentId) =>
      _loadingRepliesIds.contains(commentId);

  Future<void> toggleCommentReplies(CommentItem comment) async {
    if (_expandedRepliesIds.contains(comment.id)) {
      _expandedRepliesIds.remove(comment.id);
      notifyListeners();
      return;
    }

    _expandedRepliesIds.add(comment.id);
    if (comment.replies.isNotEmpty || comment.repliesToken == null) {
      notifyListeners();
      return;
    }

    _loadingRepliesIds.add(comment.id);
    notifyListeners();
    try {
      final fetched = await _repository.fetchCommentReplies(comment.repliesToken!);
      final video = _activeVideo;
      if (video != null) {
        final updated = video.comments
            .map((c) => c.id == comment.id ? c.copyWith(replies: fetched) : c)
            .toList();
        _activeVideo = video.copyWith(comments: updated);
      }
    } catch (_) {
    } finally {
      _loadingRepliesIds.remove(comment.id);
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
      final page = await _repository.fetchMoreComments(token);
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
    _savePersistedState();
    notifyListeners();
  }

  void clearSearchHistory() {
    _recentSearches.clear();
    _savePersistedState();
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
    _savePersistedState();
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

  Future<void> _disposeVideoController() async {
    final oldVideo = _videoController;
    final oldAudio = _audioController;
    _videoController = null;
    _audioController = null;
    if (oldVideo != null) {
      oldVideo.removeListener(_onVideoTick);
      await oldVideo.dispose();
    }
    if (oldAudio != null) {
      await oldAudio.dispose();
    }
  }

  Future<void> _initVideoController({
    String? networkUrl,
    String? audioUrl,
    String? filePath,
    Duration? startAt,
  }) async {
    await _disposeVideoController();
    final options = VideoPlayerOptions(
      allowBackgroundPlayback: _backgroundPlayEnabled,
      mixWithOthers: audioUrl != null,
    );
    final nextVideo = filePath != null
        ? VideoPlayerController.file(
            File(filePath),
            videoPlayerOptions: options,
          )
        : VideoPlayerController.networkUrl(
            Uri.parse(networkUrl!),
            videoPlayerOptions: options,
          );
    final nextAudio = audioUrl != null
        ? VideoPlayerController.networkUrl(
            Uri.parse(audioUrl),
            videoPlayerOptions: options,
          )
        : null;

    _videoController = nextVideo;
    _audioController = nextAudio;
    nextVideo.addListener(_onVideoTick);
    notifyListeners();

    try {
      await Future.wait([
        nextVideo.initialize(),
        if (nextAudio != null) nextAudio.initialize(),
      ]);
      if (_videoController != nextVideo) return;
      await nextVideo.setLooping(_isLooping);
      await nextVideo.setPlaybackSpeed(_playbackSpeed);
      await nextVideo.setVolume(
        nextAudio != null ? 0.0 : (_isMuted ? 0.0 : _volume / 100.0),
      );
      if (nextAudio != null) {
        await nextAudio.setLooping(_isLooping);
        await nextAudio.setPlaybackSpeed(_playbackSpeed);
        await nextAudio.setVolume(_isMuted ? 0.0 : _volume / 100.0);
      }
      if (startAt != null && startAt > Duration.zero) {
        await Future.wait([
          nextVideo.seekTo(startAt),
          if (nextAudio != null) nextAudio.seekTo(startAt),
        ]);
      }
      if (_isPlaying) {
        await Future.wait([
          nextVideo.play(),
          if (nextAudio != null) nextAudio.play(),
        ]);
      }
      notifyListeners();
    } catch (_) {
      notifyListeners();
    }
  }

  void _onVideoTick() {
    final player = _videoController;
    if (player == null || !player.value.isInitialized) return;

    final durationMs = player.value.duration.inMilliseconds;
    final posMs = player.value.position.inMilliseconds;
    if (durationMs > 0) {
      playbackProgressNotifier.value = (posMs / durationMs).clamp(0.0, 1.0);
    }

    if (_sponsorBlockEnabled) {
      final posSec = posMs / 1000.0;
      for (final seg in _activeSponsorSegments) {
        if (posSec >= seg.startSeconds && posSec < seg.endSeconds - 0.5) {
          player.seekTo(Duration(milliseconds: (seg.endSeconds * 1000).round()));
          break;
        }
      }
    }

    if (!_isLooping &&
        durationMs > 0 &&
        posMs >= durationMs - 300 &&
        !player.value.isPlaying &&
        !_handledEndForCurrent) {
      _handledEndForCurrent = true;
      if (_autoPlayEnabled) {
        playNextVideo();
      }
    }
  }

  void togglePlayPause() {
    if (_activeVideo == null) return;
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      _videoController?.play();
      _audioController?.play();
    } else {
      _videoController?.pause();
      _audioController?.pause();
    }
    notifyListeners();
  }

  Future<void> seekTo(double progress) async {
    final clamped = progress.clamp(0.0, 1.0);
    playbackProgressNotifier.value = clamped;
    final player = _videoController;
    if (player != null && player.value.isInitialized) {
      final target = Duration(
        milliseconds: (player.value.duration.inMilliseconds * clamped).round(),
      );
      await Future.wait([
        player.seekTo(target),
        if (_audioController != null && _audioController!.value.isInitialized)
          _audioController!.seekTo(target),
      ]);
    }
  }

  Future<void> seekBySeconds(int deltaSeconds) async {
    final player = _videoController;
    if (player != null && player.value.isInitialized) {
      final target = player.value.position + Duration(seconds: deltaSeconds);
      await Future.wait([
        player.seekTo(target),
        if (_audioController != null && _audioController!.value.isInitialized)
          _audioController!.seekTo(target),
      ]);
    }
  }

  Future<void> seekToSeconds(int seconds) async {
    final player = _videoController;
    if (player != null && player.value.isInitialized) {
      final target = Duration(seconds: seconds);
      await Future.wait([
        player.seekTo(target),
        if (_audioController != null && _audioController!.value.isInitialized)
          _audioController!.seekTo(target),
      ]);
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    final vol = _isMuted ? 0.0 : _volume / 100.0;
    if (_audioController != null) {
      _audioController!.setVolume(vol);
    } else {
      _videoController?.setVolume(vol);
    }
    notifyListeners();
  }

  void setVolumeLevel(int value) {
    _volume = value.clamp(0, 100);
    _isMuted = _volume == 0;
    final vol = _volume / 100.0;
    if (_audioController != null) {
      _audioController!.setVolume(vol);
    } else {
      _videoController?.setVolume(vol);
    }
    notifyListeners();
  }

  void setLooping(bool value) {
    _isLooping = value;
    _videoController?.setLooping(value);
    _audioController?.setLooping(value);
    notifyListeners();
  }

  void closeMiniPlayer() {
    _disposeVideoController();
    _activeVideo = null;
    _isWatchExpanded = false;
    _activeSponsorSegments = const [];
    _isPlaying = false;
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    _videoController?.setPlaybackSpeed(speed);
    _audioController?.setPlaybackSpeed(speed);
    notifyListeners();
  }

  Future<void> setQuality(String quality) async {
    _selectedQuality = quality;
    _savePersistedState();
    final track = _qualityStreams[quality];
    if (track != null && track.videoUrl.isNotEmpty && _activeVideo != null) {
      final currentPos = _videoController?.value.position;
      await _initVideoController(
        networkUrl: track.videoUrl,
        audioUrl: track.audioUrl,
        startAt: currentPos,
      );
    } else {
      notifyListeners();
    }
  }

  void createFolder(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty || _savedFolders.containsKey(cleaned)) return;
    _savedFolders[cleaned] = {};
    _savePersistedState();
    notifyListeners();
  }

  void deleteFolder(String name) {
    if (_savedFolders.remove(name) != null) {
      _savePersistedState();
      notifyListeners();
    }
  }

  void toggleVideoInFolder(String folder, String videoId) {
    final set = _savedFolders.putIfAbsent(folder, () => {});
    if (set.contains(videoId)) {
      set.remove(videoId);
    } else {
      set.add(videoId);
    }
    _savePersistedState();
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
      final path = await _repository.downloadVideoStream(
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
    _recordInterest(cleaned);
    _recentSearches.remove(cleaned);
    _recentSearches.insert(0, cleaned);
    if (_recentSearches.length > 8) {
      _recentSearches.removeLast();
    }
    notifyListeners();
  }

  void setSponsorBlock(bool value) {
    _sponsorBlockEnabled = value;
    _savePersistedState();
    notifyListeners();
  }

  void setDeArrow(bool value) {
    _deArrowEnabled = value;
    notifyListeners();
  }

  void setReturnDislike(bool value) {
    _returnDislikeEnabled = value;
    _savePersistedState();
    notifyListeners();
  }

  void setBackgroundPlay(bool value) {
    _backgroundPlayEnabled = value;
    _savePersistedState();
    notifyListeners();
  }

  void setAutoPlay(bool value) {
    _autoPlayEnabled = value;
    _savePersistedState();
    notifyListeners();
  }

  void setHideShorts(bool value) {
    _hideShortsEnabled = value;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        _backgroundPlayEnabled &&
        _isPlaying &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      _videoController!.play();
      _audioController?.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundRefreshTimer?.cancel();
    _sleepTimer?.cancel();
    _disposeVideoController();
    playbackProgressNotifier.dispose();
    _repository.dispose();
    super.dispose();
  }
}
