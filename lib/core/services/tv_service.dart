import 'package:http/http.dart' as http;
import 'package:zenplay/core/models/tv_channel.dart';

class TvService {
  TvService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  final Map<String, bool> _healthCache = {};
  DateTime? _lastHealthCheckAt;
  Future<void>? _healthCheckFuture;

  static const List<String> categories = [
    'All',
    'Bangladesh',
    'Bangla & India',
    'Sports',
    'Movies',
    'Music',
    'News',
    'Kids',
  ];

  static const Map<String, String> _defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
  };

  static const List<TvChannel> _curatedChannels = [
    // --- Bangladeshi Channels ---
    TvChannel(
      id: 'ntv_bd',
      name: 'NTV',
      category: 'Bangladesh',
      streamUrl: 'https://tvsen5.aynaott.com/xV4jEKf3D9zc/index.m3u8',
      logoUrl: 'https://i.imgur.com/l75bDTx.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'banglavision_bd',
      name: 'Bangla Vision',
      category: 'Bangladesh',
      streamUrl: 'https://tvsen5.aynaott.com/banglavision/index.m3u8',
      logoUrl: 'https://i.imgur.com/nCWgp38.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'ekushey_bd',
      name: 'Ekushey TV',
      category: 'Bangladesh',
      streamUrl: 'https://ekusheyserver.com/etvlivesn.m3u8',
      logoUrl: 'https://i.imgur.com/lRpkGHj.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'deshi_tv_bd',
      name: 'Deshi TV',
      category: 'Bangladesh',
      streamUrl: 'https://deshitv.deshitv24.net/live/myStream/playlist.m3u8',
      logoUrl: 'https://i.imgur.com/PzqzgMm.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'nexus_tv_bd',
      name: 'Nexus TV',
      category: 'Bangladesh',
      streamUrl: 'https://tvsen6.aynaott.com/Epm7WrFa/index.m3u8',
      logoUrl: 'https://i.imgur.com/XcJZKg4.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'movie_bangla_bd',
      name: 'Movie Bangla',
      category: 'Bangladesh',
      streamUrl: 'http://alvetv.com/moviebanglatv/8080/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'matribhumi_bd',
      name: 'Matribhumi TV',
      category: 'Bangladesh',
      streamUrl: 'http://live.playmax.live/matribhumi/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'rajdhani_bd',
      name: 'Rajdhani TV',
      category: 'Bangladesh',
      streamUrl: 'https://stream.shariarsuvo.com/hls5/rajdhanicable.m3u8',
      logoUrl: 'https://i.imgur.com/MBm2gPz.jpeg',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'news21_bd',
      name: 'News 21 Bangla TV',
      category: 'Bangladesh',
      streamUrl: 'http://103.190.133.68:1935/news21live/live/playlist.m3u8',
      logoUrl: 'https://i.imgur.com/ijuJfmd.png',
      httpHeaders: _defaultHeaders,
    ),

    // --- Popular Indian & Bangla Channels ---
    TvChannel(
      id: 'sony_aath',
      name: 'Sony Aath',
      category: 'Bangla & India',
      streamUrl: 'http://27.124.71.27/Sony_Aath/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'sony_max',
      name: 'Sony Max',
      category: 'Movies',
      streamUrl: 'https://drk6xq0vhn.gpcdn.net/hls/set_max_m4fb8dz2wp6kr9s_720/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'sony_sports_ten_3',
      name: 'Sony Sports Ten 3 Hindi',
      category: 'Sports',
      streamUrl: 'https://r2.amml.in/sony-ten-3-hd/live.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'sony_yay',
      name: 'Sony Yay!',
      category: 'Kids',
      streamUrl: 'https://r2.amml.in/sony-yay/live.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'star_jalsha',
      name: 'Star Jalsha HD',
      category: 'Bangla & India',
      streamUrl: 'https://da86m1sqpm3o0.cloudfront.net/28072023/smil:starjalsha.smil/chunklist_b1928000.m3u8',
      logoUrl: 'https://i.imgur.com/IlufzR5.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'zee_bangla',
      name: 'Zee Bangla HD',
      category: 'Bangla & India',
      streamUrl: 'https://raw.githubusercontent.com/amazeyourself/adaptive-streams/refs/heads/main/streams/in/YuppTV/ZeeBanglaHD.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'jalsha_movies',
      name: 'Jalsha Movies',
      category: 'Movies',
      streamUrl: 'https://box.bbaria.net:8083/Jalsha_Movie/tracks-v1a1/mono.m3u8',
      logoUrl: 'https://i.imgur.com/25eWjX2.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'aakaash_aath',
      name: 'Aakaash Aath',
      category: 'Bangla & India',
      streamUrl: 'https://cdn.pishow.tv/ott/live/969/master.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'colors_tv',
      name: 'Colors',
      category: 'Bangla & India',
      streamUrl: 'https://raw.githubusercontent.com/amazeyourself/adaptive-streams/refs/heads/main/streams/sg/YuppTV/ColorsAPAC.m3u8',
      logoUrl: 'https://i.imgur.com/M8uCJ0D.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'rupasi_bangla',
      name: 'Rupasi Bangla',
      category: 'Bangla & India',
      streamUrl: 'https://cdn.pishow.tv/ott/live/1039/master.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'enterr10_bangla',
      name: 'Enterr 10 Bangla',
      category: 'Bangla & India',
      streamUrl: 'https://amg01448-samsungin-enterr10bangla-samsungin-ad-gg.amagi.tv/playlist/amg01448-samsungin-enterr10bangla-samsungin/playlist.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'khushboo_bangla',
      name: 'Khushboo Bangla',
      category: 'Bangla & India',
      streamUrl: 'https://cdn.pishow.tv/ott/live/1473/master.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'orange_bangla',
      name: 'Orange Bangla TV',
      category: 'Bangla & India',
      streamUrl: 'https://cdn.pishow.tv/ott/live/1499/master.m3u8',
      logoUrl: 'https://i.imgur.com/wjSaHj5.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'dd_bangla',
      name: 'DD Bangla',
      category: 'Bangla & India',
      streamUrl: 'https://cdn.pishow.tv/ott/live/37/master.m3u8',
      httpHeaders: _defaultHeaders,
    ),

    // --- Sports ---
    TvChannel(
      id: 'bein_sports_usa',
      name: 'beIN Sports USA',
      category: 'Sports',
      streamUrl: 'https://tvsen6.aynaott.com/beinsports/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'dd_sports',
      name: 'DD Sports',
      category: 'Sports',
      streamUrl: 'https://d3qs3d2rkhfqrt.cloudfront.net/out/v1/b17adfe543354fdd8d189b110617cddd/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'bein_xtra_es',
      name: 'beIN Sports XTRA',
      category: 'Sports',
      streamUrl: 'https://dc1644a9jazgj.cloudfront.net/beIN_Sports_Xtra_Espanol.m3u8',
      logoUrl: 'https://i.imgur.com/V562tpO.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'acc_digital',
      name: 'ACC Digital Network',
      category: 'Sports',
      streamUrl: 'https://raycom-accdn-firetv.amagi.tv/playlist.m3u8',
      logoUrl: 'https://i.imgur.com/V6Kaqha.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'tennis_channel_2',
      name: 'Tennis Channel 2',
      category: 'Sports',
      streamUrl: 'https://mumbai-edge.smartplaytv.in/Tennis2/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'arena_sport_1',
      name: 'Arena Sport 1',
      category: 'Sports',
      streamUrl: 'http://88.212.15.50/live/test_arenasport/playlist.m3u8',
      logoUrl: 'https://i.imgur.com/2qf67zW.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'arena_4',
      name: 'Arena 4',
      category: 'Sports',
      streamUrl: 'http://88.212.7.14/live/arena4/index.m3u8',
      logoUrl: 'https://i.imgur.com/uAaQDr6.png',
      httpHeaders: _defaultHeaders,
    ),

    // --- Movies ---
    TvChannel(
      id: 'star_maa_movies',
      name: 'Star Maa Movies HD',
      category: 'Movies',
      streamUrl: 'https://da86m1sqpm3o0.cloudfront.net/28072023/smil:maamovies.smil/chunklist_b2628000.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'all_time_movies',
      name: 'All Time Movies',
      category: 'Movies',
      streamUrl: 'https://fta.ektv.in/live/54/54_0.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'alankar_tv',
      name: 'Alankar TV',
      category: 'Movies',
      streamUrl: 'https://livetv.tarangplus.in/alankar-origin/live/playlist.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'amc_europe',
      name: 'AMC Europe',
      category: 'Movies',
      streamUrl: 'http://88.212.7.14/live/amc_hun/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),

    // --- Music ---
    TvChannel(
      id: 'sangeet_bangla',
      name: 'Sangeet Bangla',
      category: 'Music',
      streamUrl: 'https://cdn.pishow.tv/ott/live/1143/master.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: '7x_music',
      name: '7X Music',
      category: 'Music',
      streamUrl: 'https://7xshreeshyam.akamaized.net/7XPunjabi/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: '7s_music',
      name: '7S Music',
      category: 'Music',
      streamUrl: 'https://cdn.pishow.tv/ott/live/1257/master.m3u8',
      logoUrl: 'https://i.imgur.com/zDiIhdN.png',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: '4_fun_dance',
      name: '4 Fun Dance',
      category: 'Music',
      streamUrl: 'http://92.114.85.87:8018/play/a00k/index.m3u8',
      logoUrl: 'https://i.imgur.com/ZEWHe1B.png',
      httpHeaders: _defaultHeaders,
    ),

    // --- News ---
    TvChannel(
      id: 'cnn_live',
      name: 'CNN',
      category: 'News',
      streamUrl: 'https://tvsen6.aynaott.com/cnn/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'bbc_south_asia',
      name: 'BBC News South Asia',
      category: 'News',
      streamUrl: 'https://mumbai-edge.smartplaytv.in/BBCNews/index.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'aaj_tak',
      name: 'Aaj Tak',
      category: 'News',
      streamUrl: 'https://d1rc86nwwc9fag.cloudfront.net/vglive-sk-791258/master.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'cnn_news18',
      name: 'CNN News 18',
      category: 'News',
      streamUrl: 'https://n18syndication.akamaized.net/bpk-tv/CNN_News18_NW18_MOB/output01/master.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'news18_bangla',
      name: 'News18 Bangla',
      category: 'News',
      streamUrl: 'https://amg01448-samsungin-news18bangla-samsungin-ad-qy.amagi.tv/playlist/amg01448-samsungin-news18bangla-samsungin/playlist.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'republic_bangla',
      name: 'Republic Bangla',
      category: 'News',
      streamUrl: 'https://cdn.pishow.tv/ott/live/270/master.m3u8',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'news_live_bangla',
      name: 'News Live Bangla',
      category: 'News',
      streamUrl: 'https://cdn.pishow.tv/ott/live/10003/master.m3u8',
      httpHeaders: _defaultHeaders,
    ),

    // --- Kids ---
    TvChannel(
      id: 'cartoon_network',
      name: 'Cartoon Network',
      category: 'Kids',
      streamUrl: 'http://103.255.250.188:5002/cs25.m3u8?channel=zhongying&gid=cs25&token=guoziyun',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'disney_channel',
      name: 'Disney Channel',
      category: 'Kids',
      streamUrl: 'http://103.255.250.188:5002/bs24.m3u8?channel=zhongying&gid=bs24&token=guoziyun',
      httpHeaders: _defaultHeaders,
    ),
    TvChannel(
      id: 'cartoonito_asia',
      name: 'Cartoonito Asia',
      category: 'Kids',
      streamUrl: 'http://cdn4.skygo.mn/live/disk1/Boomerang/HLSv3-FTA/Boomerang.m3u8',
      httpHeaders: _defaultHeaders,
    ),
  ];

  void markChannelOffline(String channelId) {
    _healthCache[channelId] = false;
  }

  Future<void> _ensureHealthChecked({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final isFresh = _lastHealthCheckAt != null &&
        now.difference(_lastHealthCheckAt!) < const Duration(minutes: 5);
    if (!forceRefresh && isFresh && _healthCache.isNotEmpty) return;

    if (forceRefresh) {
      _healthCheckFuture = null;
    }
    _healthCheckFuture ??= _runHealthCheck();
    await _healthCheckFuture;
  }

  Future<void> _runHealthCheck() async {
    try {
      await Future.wait(
        _curatedChannels.map((ch) async {
          final alive = await _isStreamAlive(ch);
          _healthCache[ch.id] = alive;
        }),
      );
      _lastHealthCheckAt = DateTime.now();
    } finally {
      _healthCheckFuture = null;
    }
  }

  Future<bool> _isStreamAlive(TvChannel channel) async {
    try {
      final res = await _http
          .get(Uri.parse(channel.streamUrl), headers: channel.httpHeaders)
          .timeout(const Duration(milliseconds: 2800));
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      if (channel.isHls && !res.body.contains('#EXTM3U')) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<TvChannel>> searchChannels(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    await _ensureHealthChecked();
    return _curatedChannels
        .where((c) =>
            (_healthCache[c.id] ?? false) &&
            (c.name.toLowerCase().contains(q) ||
                c.category.toLowerCase().contains(q)))
        .toList();
  }

  Future<List<TvChannel>> fetchChannels(
    String category, {
    bool forceRefresh = false,
  }) async {
    await _ensureHealthChecked(forceRefresh: forceRefresh);
    final alive =
        _curatedChannels.where((c) => _healthCache[c.id] ?? false).toList();
    if (category == 'All') return alive;
    if (category == 'Bangla & India') {
      return alive
          .where((c) =>
              c.category == 'Bangladesh' ||
              c.category == 'Bangla & India' ||
              c.name.contains('Sony') ||
              c.name.contains('Bangla') ||
              c.name.contains('Jalsha') ||
              c.name.contains('Aaj Tak') ||
              c.name.contains('DD '))
          .toList();
    }
    if (category == 'Movies') {
      return alive
          .where((c) =>
              c.category == 'Movies' ||
              c.id == 'movie_bangla_bd' ||
              c.id == 'sony_aath')
          .toList();
    }
    return alive.where((c) => c.category == category).toList();
  }

  static List<TvChannel> parseM3u(
    String content, {
    required String defaultCategory,
  }) {
    final lines = content.split(RegExp(r'\r?\n'));
    final bestByKey = <String, TvChannel>{};
    final seenUrls = <String>{};

    String? pendingId;
    String? pendingLogo;
    String? pendingGroup;
    String? pendingName;
    String? pendingUserAgent;
    String? pendingReferrer;

    void resetPending() {
      pendingId = null;
      pendingLogo = null;
      pendingGroup = null;
      pendingName = null;
      pendingUserAgent = null;
      pendingReferrer = null;
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        pendingId = _extractAttr(line, 'tvg-id');
        pendingLogo = _extractAttr(line, 'tvg-logo');
        pendingGroup = _extractAttr(line, 'group-title');
        final commaIdx = line.lastIndexOf(',');
        pendingName = commaIdx != -1 && commaIdx + 1 < line.length
            ? line.substring(commaIdx + 1).trim()
            : null;
        continue;
      }

      if (line.startsWith('#EXTVLCOPT:http-user-agent=')) {
        pendingUserAgent =
            line.substring('#EXTVLCOPT:http-user-agent='.length).trim();
        continue;
      }

      if (line.startsWith('#EXTVLCOPT:http-referrer=')) {
        pendingReferrer =
            line.substring('#EXTVLCOPT:http-referrer='.length).trim();
        continue;
      }

      if (line.startsWith('#')) continue;

      final uri = Uri.tryParse(line);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        resetPending();
        continue;
      }

      final rawName = pendingName;
      final rawGroup = pendingGroup;
      final rawId = pendingId;
      final rawLogo = pendingLogo;
      final rawUserAgent = pendingUserAgent;
      final rawReferrer = pendingReferrer;

      final name = (rawName != null && rawName.isNotEmpty)
          ? rawName
          : 'Live Channel ${bestByKey.length + 1}';

      final lowerName = name.toLowerCase();
      if (lowerName.contains('[geo-blocked]') ||
          lowerName.contains('[not 24/7]')) {
        resetPending();
        continue;
      }

      if (!seenUrls.add(line)) {
        resetPending();
        continue;
      }

      final category = (rawGroup != null && rawGroup.isNotEmpty)
          ? rawGroup.split(';').first.trim()
          : defaultCategory;

      final id = (rawId != null && rawId.isNotEmpty)
          ? rawId
          : '${slugify(name)}_${bestByKey.length}';

      final headers = <String, String>{
        'User-Agent': (rawUserAgent != null && rawUserAgent.isNotEmpty)
            ? rawUserAgent
            : _defaultHeaders['User-Agent']!,
        if (rawReferrer != null && rawReferrer.isNotEmpty)
          'Referer': rawReferrer,
      };

      final lowerUrl = line.toLowerCase();
      final candidate = TvChannel(
        id: id,
        name: _cleanDisplayName(name),
        category: category,
        streamUrl: line,
        logoUrl:
            (rawLogo != null && rawLogo.startsWith('http')) ? rawLogo : null,
        isHls: lowerUrl.contains('.m3u8') || lowerUrl.contains('.m3u'),
        httpHeaders: headers,
      );

      final key = _normalizeChannelKey(name);
      bestByKey.putIfAbsent(key, () => candidate);
      resetPending();
    }

    return bestByKey.values.toList();
  }

  static String _cleanDisplayName(String name) {
    return name
        .replaceAll(
          RegExp(
            r'\s*\((?:1080p|720p|576p|480p|360p|240p|2160p|4K)\)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s*\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeChannelKey(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\b(uhd|fhd|hd|sd)\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  /// Verifies the stream is reachable (following redirects) and returns the
  /// final playable URL, or null if the origin server is offline/unreachable.
  Future<String?> resolveFastStreamUrl(TvChannel channel) async {
    try {
      final res = await _http
          .get(Uri.parse(channel.streamUrl), headers: channel.httpHeaders)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final finalUrl = res.request?.url ?? Uri.parse(channel.streamUrl);
      if (channel.isHls && !res.body.contains('#EXTM3U')) {
        return null;
      }
      return finalUrl.toString();
    } catch (_) {
      return null;
    }
  }

  static String? _extractAttr(String line, String attr) {
    final match = RegExp('$attr="([^"]*)"').firstMatch(line);
    final value = match?.group(1)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static String slugify(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  void dispose() {
    _http.close();
  }
}
