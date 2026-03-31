import 'dart:typed_data';

import '../models/file_item.dart';
import '../models/folder_node.dart';

abstract class ExplorerRepository {
  Future<String> ensureRootFolder();

  Future<List<FolderNode>> fetchFolders();

  Future<List<FileItem>> fetchFiles(String folderId);

  Future<FolderNode> createFolder({required String name, String? parentId});

  Future<void> renameFolder({
    required String folderId,
    required String newName,
  });

  Future<void> moveFolder({
    required String folderId,
    required String? newParentId,
  });

  Future<void> deleteFolder(String folderId);

  Future<FileItem> uploadFile({
    required String localPath,
    required String folderId,
  });

  Future<void> renameFile({required String fileId, required String newName});

  Future<void> moveFile({
    required String fileId,
    required String targetFolderId,
  });

  Future<void> deleteFile(FileItem file);

  Future<Uint8List> downloadFile(String storagePath);

  Stream<void> watchChanges();
}
