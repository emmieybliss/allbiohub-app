import 'media_image.dart';

class Founder {
  const Founder({required this.name, this.role, this.profileUrl});

  factory Founder.fromJson(Map<String, dynamic> json) => Founder(
    name: json['name'] as String,
    role: json['role'] as String?,
    profileUrl: json['url'] as String?,
  );

  final String name;
  final String? role;
  final String? profileUrl;

  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    'url': profileUrl,
  };
}

/// A startup from the AllBioHub directory. Every field except the identity
/// fields is optional because profiles vary in completeness; the UI shows
/// only what the backend supplies and never infers badges.
class Startup {
  const Startup({
    required this.id,
    required this.slug,
    required this.name,
    required this.link,
    this.tagline,
    this.description,
    this.logo,
    this.industry,
    this.country,
    this.city,
    this.foundedYear,
    this.stage,
    this.funding,
    this.businessModel,
    this.employees,
    this.status,
    this.website,
    this.socialLinks = const {},
    this.founders = const [],
    this.products = const [],
    this.verified = false,
    this.claimed = false,
    this.featured = false,
    this.createdAt,
    this.updatedAt,
    this.verifiedAt,
  });

  factory Startup.fromJson(Map<String, dynamic> json) {
    String? str(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = '$v'.trim();
      return s.isEmpty ? null : s;
    }

    DateTime? date(String key) => DateTime.tryParse(str(key) ?? '');

    final logo = json['logo'];
    return Startup(
      id: json['id'] as int,
      slug: json['slug'] as String,
      name: json['name'] as String,
      link: json['link'] as String,
      tagline: str('tagline'),
      description: str('description'),
      logo: switch (logo) {
        final String url when url.isNotEmpty => MediaImage.single(url),
        final Map<String, dynamic> m => MediaImage.fromJson(m),
        _ => null,
      },
      industry: str('industry'),
      country: str('country'),
      city: str('city'),
      foundedYear: json['founded'] is int
          ? json['founded'] as int
          : int.tryParse(str('founded') ?? ''),
      stage: str('stage'),
      funding: str('funding'),
      businessModel: str('business_model'),
      employees: str('employees'),
      status: str('status'),
      website: str('website'),
      socialLinks: {
        for (final e
            in (json['social'] as Map<String, dynamic>? ?? const {}).entries)
          if (e.value is String && (e.value as String).isNotEmpty)
            e.key: e.value as String,
      },
      founders: [
        for (final f in json['founders'] as List<dynamic>? ?? const [])
          Founder.fromJson(f as Map<String, dynamic>),
      ],
      products: [
        for (final p in json['products'] as List<dynamic>? ?? const []) '$p',
      ],
      verified: json['verified'] == true,
      claimed: json['claimed'] == true,
      featured: json['featured'] == true,
      createdAt: date('created_at'),
      updatedAt: date('updated_at'),
      verifiedAt: date('verified_at'),
    );
  }

  final int id;
  final String slug;
  final String name;

  /// Canonical profile URL on allbiohub.com.
  final String link;
  final String? tagline;
  final String? description;
  final MediaImage? logo;
  final String? industry;
  final String? country;
  final String? city;
  final int? foundedYear;
  final String? stage;
  final String? funding;
  final String? businessModel;
  final String? employees;
  final String? status;
  final String? website;
  final Map<String, String> socialLinks;
  final List<Founder> founders;
  final List<String> products;
  final bool verified;
  final bool claimed;
  final bool featured;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? verifiedAt;

  String? get location =>
      [city, country].whereType<String>().join(', ').nullIfEmpty;

  String get summary => tagline ?? description ?? '';
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// A filter value offered by the directory, with how many startups match.
class FilterOption {
  const FilterOption({required this.value, required this.label, this.count});

  factory FilterOption.fromJson(Object json) => switch (json) {
    final String s => FilterOption(value: s, label: s),
    final Map<String, dynamic> m => FilterOption(
      value: '${m['value'] ?? m['slug'] ?? m['label']}',
      label: '${m['label'] ?? m['name'] ?? m['value']}',
      count: m['count'] as int?,
    ),
    _ => throw const FormatException('Invalid filter option'),
  };

  final String value;
  final String label;
  final int? count;
}

/// Filter dimensions the backend supports. Lists are empty when a dimension
/// isn't available, and the UI hides that filter.
class StartupFilterOptions {
  const StartupFilterOptions({
    this.industries = const [],
    this.countries = const [],
    this.stages = const [],
    this.businessModels = const [],
    this.employeeRanges = const [],
    this.fundings = const [],
  });

  factory StartupFilterOptions.fromJson(Map<String, dynamic> json) {
    List<FilterOption> list(String key) => [
      for (final o in json[key] as List<dynamic>? ?? const [])
        FilterOption.fromJson(o as Object),
    ];
    return StartupFilterOptions(
      industries: list('industries'),
      countries: list('countries'),
      stages: list('stages'),
      businessModels: list('business_models'),
      employeeRanges: list('employees'),
      fundings: list('funding'),
    );
  }

  final List<FilterOption> industries;
  final List<FilterOption> countries;
  final List<FilterOption> stages;
  final List<FilterOption> businessModels;
  final List<FilterOption> employeeRanges;
  final List<FilterOption> fundings;
}

enum StartupSort { newest, updated, name, verified }

/// A directory query. Null fields are not sent.
class StartupQuery {
  const StartupQuery({
    this.search,
    this.industry,
    this.country,
    this.city,
    this.stage,
    this.funding,
    this.businessModel,
    this.employees,
    this.foundedFrom,
    this.foundedTo,
    this.verified,
    this.claimed,
    this.featured,
    this.sort = StartupSort.newest,
  });

  final String? search;
  final String? industry;
  final String? country;
  final String? city;
  final String? stage;
  final String? funding;
  final String? businessModel;
  final String? employees;
  final int? foundedFrom;
  final int? foundedTo;
  final bool? verified;
  final bool? claimed;
  final bool? featured;
  final StartupSort sort;

  int get activeFilterCount => [
    industry,
    country,
    city,
    stage,
    funding,
    businessModel,
    employees,
    foundedFrom,
    foundedTo,
    verified,
    claimed,
    featured,
  ].where((v) => v != null).length;

  Map<String, Object?> toQuery() => {
    'search': search,
    'industry': industry,
    'country': country,
    'city': city,
    'stage': stage,
    'funding': funding,
    'business_model': businessModel,
    'employees': employees,
    'founded_from': foundedFrom,
    'founded_to': foundedTo,
    'verified': verified == null ? null : (verified! ? 1 : 0),
    'claimed': claimed == null ? null : (claimed! ? 1 : 0),
    'featured': featured == null ? null : (featured! ? 1 : 0),
    'orderby': sort.name,
  };

  StartupQuery copyWith({
    String? Function()? search,
    String? Function()? industry,
    String? Function()? country,
    String? Function()? city,
    String? Function()? stage,
    String? Function()? funding,
    String? Function()? businessModel,
    String? Function()? employees,
    int? Function()? foundedFrom,
    int? Function()? foundedTo,
    bool? Function()? verified,
    bool? Function()? claimed,
    bool? Function()? featured,
    StartupSort? sort,
  }) => StartupQuery(
    search: search == null ? this.search : search(),
    industry: industry == null ? this.industry : industry(),
    country: country == null ? this.country : country(),
    city: city == null ? this.city : city(),
    stage: stage == null ? this.stage : stage(),
    funding: funding == null ? this.funding : funding(),
    businessModel: businessModel == null ? this.businessModel : businessModel(),
    employees: employees == null ? this.employees : employees(),
    foundedFrom: foundedFrom == null ? this.foundedFrom : foundedFrom(),
    foundedTo: foundedTo == null ? this.foundedTo : foundedTo(),
    verified: verified == null ? this.verified : verified(),
    claimed: claimed == null ? this.claimed : claimed(),
    featured: featured == null ? this.featured : featured(),
    sort: sort ?? this.sort,
  );

  StartupQuery clearFilters() => StartupQuery(search: search, sort: sort);

  @override
  bool operator ==(Object other) =>
      other is StartupQuery &&
      other.toQuery().toString() == toQuery().toString();

  @override
  int get hashCode => toQuery().toString().hashCode;
}
