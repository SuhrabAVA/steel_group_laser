import '../core/utils/file_formatters.dart';

class FileItem {
  const FileItem({
    required this.id,
    required this.ownerId,
    required this.folderId,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.storagePath,
    required this.createdAt,
    required this.updatedAt,
    this.mimeType,
  });

  final String id;
  final String ownerId;
  final String folderId;
  final String name;
  final String extension;
  final String? mimeType;
  final int sizeBytes;
  final String storagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get normalizedExtension {
    if (extension.isNotEmpty) {
      return extension.toLowerCase();
    }
    return extensionFromName(name);
  }

  FileItem copyWith({
    String? id,
    String? ownerId,
    String? folderId,
    String? name,
    String? extension,
    String? mimeType,
    int? sizeBytes,
    String? storagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FileItem(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      folderId: folderId ?? this.folderId,
      name: name ?? this.name,
      extension: extension ?? this.extension,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      storagePath: storagePath ?? this.storagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FileItem.fromMap(Map<String, dynamic> map) {
    return FileItem(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      folderId: map['folder_id'] as String,
      name: map['name'] as String,
      extension: (map['extension'] as String?) ?? '',
      mimeType: map['mime_type'] as String?,
      sizeBytes: (map['size_bytes'] as num).toInt(),
      storagePath: map['storage_path'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'folder_id': folderId,
      'name': name,
      'extension': extension,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'storage_path': storagePath,
    };
  }
}
