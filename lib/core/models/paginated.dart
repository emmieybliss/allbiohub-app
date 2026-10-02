/// One page of results from a paginated endpoint.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    this.totalPages,
    this.total,
    this.stale = false,
  });

  final List<T> items;
  final int page;
  final int? totalPages;
  final int? total;

  /// Loaded from the offline cache after a network failure.
  final bool stale;

  bool get hasMore =>
      totalPages == null ? items.isNotEmpty : page < totalPages!;
}
