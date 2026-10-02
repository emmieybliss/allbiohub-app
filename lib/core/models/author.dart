class Author {
  const Author({
    required this.id,
    required this.name,
    this.slug = '',
    this.avatarUrl,
  });

  factory Author.fromJson(Map<String, dynamic> json) => Author(
    id: json['id'] as int,
    name: json['name'] as String,
    slug: json['slug'] as String? ?? '',
    avatarUrl: json['avatar'] as String?,
  );

  final int id;
  final String name;
  final String slug;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'avatar': avatarUrl,
  };
}
