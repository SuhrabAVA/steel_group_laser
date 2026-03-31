import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../models/explorer_entry.dart';
import '../models/file_item.dart';
import '../models/folder_node.dart';
import '../repositories/explorer_repository.dart';
import 'explorer_state.dart';

class ExplorerController extends StateNotifier<ExplorerState> {
  ExplorerController({required ExplorerRepository repository})
    : _repository = repository,
      super(const ExplorerState.initial());

  final ExplorerRepository _repository;

  bool _didInitialize = false;

  Future<void> initialize() async {
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    await refresh();
  }

  Future<void> refresh({String? targetFolderId, bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final ensuredRootId = await _repository.ensureRootFolder();
      final folders = await _repository.fetchFolders();
      final resolvedFolderId = _resolveCurrentFolderId(
        folders: folders,
        preferredId: targetFolderId ?? state.currentFolderId ?? ensuredRootId,
      );
      final files = resolvedFolderId == null
          ? <FileItem>[]
          : await _repository.fetchFiles(resolvedFolderId);

      state = state.copyWith(
        folders: folders,
        files: files,
        currentFolderId: resolvedFolderId,
        selectedItemKeys: <String>{},
        isLoading: false,
        initialized: true,
        clearError: true,
      );
    } catch (error, stackTrace) {
      final appException = _toAppException(error, stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: appException.message,
      );
      throw appException;
    }
  }

  Future<void> openFolder(String folderId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final files = await _repository.fetchFiles(folderId);
      state = state.copyWith(
        files: files,
        currentFolderId: folderId,
        selectedItemKeys: <String>{},
        isLoading: false,
      );
    } catch (error, stackTrace) {
      final appException = _toAppException(error, stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: appException.message,
      );
      throw appException;
    }
  }

  Future<void> createFolder(String name, {String? parentId}) async {
    await _mutate(() async {
      await _repository.createFolder(
        name: name,
        parentId: parentId ?? state.currentFolderId,
      );
    });
  }

  Future<void> renameFolder({
    required String folderId,
    required String newName,
  }) async {
    await _mutate(() async {
      await _repository.renameFolder(folderId: folderId, newName: newName);
    });
  }

  Future<void> moveFolder({
    required String folderId,
    required String? targetParentId,
  }) async {
    final folder = state.folders.firstWhereOrNull(
      (item) => item.id == folderId,
    );
    if (folder == null) {
      throw const AppException('Папка не найдена.');
    }
    if (folder.parentId == null) {
      throw const AppException('Корневую папку нельзя переместить.');
    }

    if (targetParentId == folderId) {
      throw const AppException('Нельзя переместить папку в саму себя.');
    }

    final descendants = collectDescendantFolderIds(folderId);
    if (targetParentId != null && descendants.contains(targetParentId)) {
      throw const AppException('Нельзя переместить папку в ее собственную вложенную папку.');
    }

    await _mutate(() async {
      await _repository.moveFolder(
        folderId: folderId,
        newParentId: targetParentId,
      );
    });
  }

  Future<void> deleteFolder(String folderId) async {
    final folder = state.folders.firstWhereOrNull(
      (item) => item.id == folderId,
    );
    if (folder == null) {
      throw const AppException('Папка не найдена.');
    }
    if (folder.parentId == null) {
      throw const AppException('Корневую папку нельзя удалить.');
    }

    await _mutate(() async {
      await _repository.deleteFolder(folderId);
    }, focusFolderId: folder.parentId);
  }

  Future<void> uploadFiles(List<String> localPaths) async {
    final currentFolderId = state.currentFolderId;
    if (currentFolderId == null || localPaths.isEmpty) {
      return;
    }

    await _mutate(() async {
      for (final path in localPaths) {
        if (path.trim().isEmpty) {
          continue;
        }
        await _repository.uploadFile(
          localPath: path,
          folderId: currentFolderId,
        );
      }
    });
  }

  Future<void> renameFile({
    required String fileId,
    required String newName,
  }) async {
    await _mutate(() async {
      await _repository.renameFile(fileId: fileId, newName: newName);
    });
  }

  Future<void> moveFile({
    required String fileId,
    required String targetFolderId,
  }) async {
    await _mutate(() async {
      await _repository.moveFile(
        fileId: fileId,
        targetFolderId: targetFolderId,
      );
    });
  }

  Future<void> deleteFile(FileItem file) async {
    await _mutate(() async {
      await _repository.deleteFile(file);
    });
  }

  Future<List<int>> downloadFile(String storagePath) async {
    try {
      final bytes = await _repository.downloadFile(storagePath);
      return bytes;
    } catch (error, stackTrace) {
      final appException = _toAppException(error, stackTrace);
      state = state.copyWith(errorMessage: appException.message);
      throw appException;
    }
  }

  void selectItem({required String selectionKey, required bool additive}) {
    final next = <String>{...state.selectedItemKeys};

    if (!additive) {
      state = state.copyWith(selectedItemKeys: {selectionKey});
      return;
    }

    if (next.contains(selectionKey)) {
      next.remove(selectionKey);
    } else {
      next.add(selectionKey);
    }

    state = state.copyWith(selectedItemKeys: next);
  }

  void clearSelection() {
    state = state.copyWith(selectedItemKeys: <String>{});
  }

  void setGridMode(bool value) {
    state = state.copyWith(gridMode: value);
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void setDragHovering(bool value) {
    state = state.copyWith(isDragHovering: value);
  }

  List<FolderNode> foldersInCurrent() {
    final currentFolderId = state.currentFolderId;
    if (currentFolderId == null) {
      return const [];
    }

    final query = state.searchQuery.trim().toLowerCase();

    return state.folders
        .where((folder) => folder.parentId == currentFolderId)
        .where((folder) {
          if (query.isEmpty) {
            return true;
          }
          return folder.name.toLowerCase().contains(query);
        })
        .sortedBy((folder) => folder.name.toLowerCase());
  }

  List<FileItem> filesInCurrent() {
    final query = state.searchQuery.trim().toLowerCase();

    return state.files
        .where((file) {
          if (query.isEmpty) {
            return true;
          }
          return file.name.toLowerCase().contains(query);
        })
        .sortedBy((file) => file.name.toLowerCase());
  }

  List<ExplorerEntry> currentEntries() {
    final folderEntries = foldersInCurrent().map(ExplorerEntry.folder);
    final fileEntries = filesInCurrent().map(ExplorerEntry.file);
    return [...folderEntries, ...fileEntries];
  }

  List<FolderNode> buildBreadcrumb() {
    final currentFolderId = state.currentFolderId;
    if (currentFolderId == null) {
      return const [];
    }

    final byId = {for (final folder in state.folders) folder.id: folder};
    final breadcrumb = <FolderNode>[];
    final visited = <String>{};

    var pointer = byId[currentFolderId];
    while (pointer != null && !visited.contains(pointer.id)) {
      visited.add(pointer.id);
      breadcrumb.add(pointer);
      pointer = pointer.parentId == null ? null : byId[pointer.parentId!];
    }

    return breadcrumb.reversed.toList();
  }

  Set<String> collectDescendantFolderIds(String folderId) {
    final descendants = <String>{};

    void crawl(String parent) {
      final children = state.folders.where(
        (folder) => folder.parentId == parent,
      );
      for (final child in children) {
        if (descendants.add(child.id)) {
          crawl(child.id);
        }
      }
    }

    crawl(folderId);
    return descendants;
  }

  Future<void> _mutate(
    Future<void> Function() action, {
    String? focusFolderId,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);

    try {
      await action();
      await refresh(
        targetFolderId: focusFolderId ?? state.currentFolderId,
        silent: true,
      );
    } catch (error, stackTrace) {
      final appException = _toAppException(error, stackTrace);
      state = state.copyWith(errorMessage: appException.message);
      throw appException;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  String? _resolveCurrentFolderId({
    required List<FolderNode> folders,
    required String? preferredId,
  }) {
    if (folders.isEmpty) {
      return null;
    }

    if (preferredId != null &&
        folders.any((folder) => folder.id == preferredId)) {
      return preferredId;
    }

    final root =
        folders.firstWhereOrNull((folder) => folder.parentId == null) ??
        folders.first;
    return root.id;
  }

  AppException _toAppException(Object error, StackTrace stackTrace) {
    if (error is AppException) {
      return AppException(
        error.message,
        cause: error.cause,
        stackTrace: stackTrace,
      );
    }

    return AppException(error.toString(), cause: error, stackTrace: stackTrace);
  }
}
