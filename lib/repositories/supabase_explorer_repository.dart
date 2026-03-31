import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/file_formatters.dart';
import '../models/file_item.dart';
import '../models/folder_node.dart';
import 'explorer_repository.dart';

class SupabaseExplorerRepository implements ExplorerRepository {
  SupabaseExplorerRepository(this._client, {required this.bucketName});

  final SupabaseClient _client;
  final String bucketName;
  final Uuid _uuid = const Uuid();

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppException('Пользователь не авторизован.');
    }
    return user;
  }

  @override
  Future<String> ensureRootFolder() async {
    _requireUser();
    try {
      final result = await _client.rpc(
        'ensure_user_root_folder',
        params: {'root_name': 'Главная'},
      );

      if (result is String && result.isNotEmpty) {
        return result;
      }

      if (result is Map<String, dynamic>) {
        final dynamic id = result['id'] ?? result['ensure_user_root_folder'];
        if (id is String && id.isNotEmpty) {
          return id;
        }
      }

      throw const AppException('Не удалось определить корневую папку.');
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<List<FolderNode>> fetchFolders() async {
    _requireUser();
    try {
      final response = await _client
          .from('folders')
          .select()
          .order('path')
          .order('name');

      return (response as List<dynamic>)
          .map((row) => FolderNode.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<List<FileItem>> fetchFiles(String folderId) async {
    _requireUser();
    try {
      final response = await _client
          .from('files')
          .select()
          .eq('folder_id', folderId)
          .order('name');

      return (response as List<dynamic>)
          .map((row) => FileItem.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<FolderNode> createFolder({
    required String name,
    String? parentId,
  }) async {
    final user = _requireUser();
    final safeName = _sanitizeFolderName(name);
    try {
      final response = await _client
          .from('folders')
          .insert({
            'owner_id': user.id,
            'parent_id': parentId,
            'name': safeName,
            'path': '',
          })
          .select()
          .single();

      return FolderNode.fromMap(response);
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<void> renameFolder({
    required String folderId,
    required String newName,
  }) async {
    final safeName = _sanitizeFolderName(newName);
    try {
      await _client
          .from('folders')
          .update({'name': safeName})
          .eq('id', folderId)
          .select();
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<void> moveFolder({
    required String folderId,
    required String? newParentId,
  }) async {
    try {
      await _client
          .from('folders')
          .update({'parent_id': newParentId})
          .eq('id', folderId)
          .select();
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    _requireUser();
    try {
      final response = await _client.rpc(
        'list_folder_storage_paths',
        params: {'target_folder': folderId},
      );

      final paths = <String>[];
      if (response is List) {
        for (final row in response) {
          if (row is Map<String, dynamic>) {
            final path = row['storage_path'] as String?;
            if (path != null && path.isNotEmpty) {
              paths.add(path);
            }
          }
        }
      }

      if (paths.isNotEmpty) {
        await _client.storage.from(bucketName).remove(paths);
      }

      await _client.from('folders').delete().eq('id', folderId);
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<FileItem> uploadFile({
    required String localPath,
    required String folderId,
  }) async {
    final user = _requireUser();
    final localFile = File(localPath);
    if (!localFile.existsSync()) {
      throw const AppException('Файл не найден на локальном диске.');
    }

    final rawName = p.basename(localFile.path);
    final fileName = _sanitizeFileName(rawName);
    final fileId = _uuid.v4();
    final storagePath = '${user.id}/$fileId/$fileName';
    final extension = extensionFromName(fileName);
    final mimeType = lookupMimeType(localFile.path);
    final sizeBytes = await localFile.length();

    try {
      await _client.storage
          .from(bucketName)
          .upload(
            storagePath,
            localFile,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );

      final response = await _client
          .from('files')
          .insert({
            'id': fileId,
            'owner_id': user.id,
            'folder_id': folderId,
            'name': fileName,
            'extension': extension,
            'mime_type': mimeType,
            'size_bytes': sizeBytes,
            'storage_path': storagePath,
          })
          .select()
          .single();

      return FileItem.fromMap(response);
    } catch (error, stackTrace) {
      try {
        await _client.storage.from(bucketName).remove([storagePath]);
      } catch (_) {
        // If rollback fails, the DB operation still fails and file can be cleaned later.
      }
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<void> renameFile({
    required String fileId,
    required String newName,
  }) async {
    final safeName = _sanitizeFileName(newName);
    final extension = extensionFromName(safeName);

    try {
      await _client
          .from('files')
          .update({'name': safeName, 'extension': extension})
          .eq('id', fileId)
          .select();
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<void> moveFile({
    required String fileId,
    required String targetFolderId,
  }) async {
    try {
      await _client
          .from('files')
          .update({'folder_id': targetFolderId})
          .eq('id', fileId)
          .select();
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<void> deleteFile(FileItem file) async {
    try {
      await _client.storage.from(bucketName).remove([file.storagePath]);
      await _client.from('files').delete().eq('id', file.id);
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  @override
  Future<Uint8List> downloadFile(String storagePath) async {
    try {
      return await _client.storage.from(bucketName).download(storagePath);
    } catch (error, stackTrace) {
      throw _toAppException(error, stackTrace);
    }
  }

  AppException _toAppException(Object error, StackTrace stackTrace) {
    if (error is AppException) {
      return AppException(
        error.message,
        cause: error.cause,
        stackTrace: stackTrace,
      );
    }

    if (error is PostgrestException) {
      if (error.code == '23505') {
        return AppException(
          'Конфликт имен: элемент с таким именем уже существует в целевой папке.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
      return AppException(error.message, cause: error, stackTrace: stackTrace);
    }

    if (error is AuthException) {
      return AppException(error.message, cause: error, stackTrace: stackTrace);
    }

    if (error is StorageException) {
      return AppException(error.message, cause: error, stackTrace: stackTrace);
    }

    return AppException(error.toString(), cause: error, stackTrace: stackTrace);
  }

  String _sanitizeFolderName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (cleaned.isEmpty) {
      throw const AppException('Имя папки не может быть пустым.');
    }
    return cleaned;
  }

  String _sanitizeFileName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (cleaned.isEmpty) {
      throw const AppException('Имя файла не может быть пустым.');
    }
    return cleaned;
  }
}
