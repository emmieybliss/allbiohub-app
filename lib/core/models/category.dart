enum TermKind { category, tag }

/// A WordPress category or tag.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.kind = TermKind.category,
    this.count = 0,
    this.description = '',
    this.parentId = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as int,
    name: json['name'] as String,
    slug: json['slug'] as String,
    kind: json['kind'] == 'tag' ? TermKind.tag : TermKind.category,
    count: json['count'] as int? ?? 0,
    description: json['description'] as String? ?? '',
    parentId: json['parent'] as int? ?? 0,
  );

  final int id;
  final String name;
  final String slug;
  final TermKind kind;
  final int count;
  final String description;
  final int parentId;

  /// Site names are uppercase ("CELEBRITY NEWS"); the app uses title case.
  String get displayName => name
      .toLowerCase()
      .split(' ')
      .map(
        (w) => w.isEmpty || w == '&'
            ? w
            : '${w[0].toUpperCase()}${w.substring(1)}',
      )
      .join(' ');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'kind': kind.name,
    'count': count,
    'description': description,
    'parent': parentId,
  };

  @override
  bool operator ==(Object other) =>
      other is Category && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);
}
