class TvChannel {
  const TvChannel({
    required this.id,
    required this.name,
    required this.category,
    required this.streamUrl,
    this.logoUrl,
    this.country,
    this.isHls = true,
    this.httpHeaders = const {},
  });

  final String id;
  final String name;
  final String category;
  final String streamUrl;
  final String? logoUrl;
  final String? country;
  final bool isHls;
  final Map<String, String> httpHeaders;
}
