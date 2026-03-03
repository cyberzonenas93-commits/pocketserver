/// A file stored for transfer (uploaded from another device).
class TransferItem {
  final String id;
  final String name;
  final int sizeBytes;
  final TransferItemType type;
  final String relativePath; // path relative to storage root

  const TransferItem({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.type,
    required this.relativePath,
  });

  String get displayName => name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sizeBytes': sizeBytes,
        'type': type.name,
        'relativePath': relativePath,
      };

  factory TransferItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'other';
    TransferItemType type;
    try {
      type = TransferItemType.values.byName(typeStr);
    } catch (_) {
      type = TransferItemType.other;
    }
    return TransferItem(
      id: json['id'] as String,
      name: json['name'] as String,
      sizeBytes: json['sizeBytes'] as int,
      type: type,
      relativePath: json['relativePath'] as String,
    );
  }
}

enum TransferItemType { photo, video, other }
