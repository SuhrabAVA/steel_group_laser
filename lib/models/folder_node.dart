class FolderNode {
  const FolderNode({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.path,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
  });

  final String id;
  final String ownerId;
  final String? parentId;
  final String name;
  final String path;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRoot => parentId == null;

  int get depth {
    final segments = path
        .split('/')
        .where((segment) => segment.trim().isNotEmpty);
    return segments.length - 1;
  }

  FolderNode copyWith({
    String? id,
    String? ownerId,
    String? parentId,
    String? name,
    String? path,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FolderNode(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FolderNode.fromMap(Map<String, dynamic> map) {
    return FolderNode(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      parentId: map['parent_id'] as String?,
      name: map['name'] as String,
      path: map['path'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'parent_id': parentId,
      'name': name,
      'path': path,
    };
  }
}
