import 'dart:io';

import 'package:collection/collection.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/app_exception.dart';
import '../../core/extensions/date_formatters.dart';
import '../../core/utils/file_formatters.dart';
import '../../models/explorer_drag_payload.dart';
import '../../models/explorer_entry.dart';
import '../../models/file_item.dart';
import '../../models/folder_node.dart';
import '../../state/app_providers.dart';
import '../../state/explorer_state.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/explorer_items_view.dart';
import '../widgets/sidebar_folder_tree.dart';

enum _CanvasAction { createFolder, uploadFile, refresh }

enum _EntryAction {
  open,
  rename,
  delete,
  move,
  download,
  refresh,
  copyPath,
  info,
  createFolder,
  uploadFile,
}

class ExplorerPage extends ConsumerStatefulWidget {
  const ExplorerPage({super.key});

  @override
  ConsumerState<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends ConsumerState<ExplorerPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(explorerControllerProvider.notifier).initialize();
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showError(error.toString());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ExplorerState>(explorerControllerProvider, (previous, next) {
      final previousError = previous?.errorMessage;
      if (next.errorMessage != null && next.errorMessage != previousError) {
        _showError(next.errorMessage!);
      }
    });

    final state = ref.watch(explorerControllerProvider);
    final controller = ref.read(explorerControllerProvider.notifier);

    final breadcrumb = controller.buildBreadcrumb();
    final entries = controller.currentEntries();
    final selectedEntry = _singleSelectedEntry(entries, state.selectedItemKeys);

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(state, selectedEntry),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 310,
                  child: SidebarFolderTree(
                    folders: state.folders,
                    currentFolderId: state.currentFolderId,
                    onFolderTap: (folderId) async {
                      await _guarded(() => controller.openFolder(folderId));
                    },
                    onFolderContext: _showFolderContextMenu,
                    onFolderDrop: (payload, targetFolder) async {
                      await _handleInternalDrop(payload, targetFolder.id);
                    },
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 54,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: const BoxDecoration(
                          color: AppColors.panelElevated,
                          border: Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: BreadcrumbBar(
                            breadcrumb: breadcrumb,
                            onTap: (folderId) async {
                              await _guarded(
                                () => controller.openFolder(folderId),
                              );
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: DropTarget(
                          onDragEntered: (_) =>
                              controller.setDragHovering(true),
                          onDragExited: (_) =>
                              controller.setDragHovering(false),
                          onDragDone: (details) async {
                            controller.setDragHovering(false);
                            final paths = details.files
                                .map((item) => item.path)
                                .where((path) => path.trim().isNotEmpty)
                                .toList();
                            if (paths.isEmpty) {
                              return;
                            }
                            await _guarded(() async {
                              await controller.uploadFiles(paths);
                              _showSuccess('Uploaded ${paths.length} file(s)');
                            });
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: controller.clearSelection,
                            onSecondaryTapDown: (details) {
                              _showCanvasContextMenu(details.globalPosition);
                            },
                            child: Stack(
                              children: [
                                Container(
                                  color: AppColors.background,
                                  child: state.isLoading && !state.initialized
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : ExplorerItemsView(
                                          entries: entries,
                                          gridMode: state.gridMode,
                                          selectedKeys: state.selectedItemKeys,
                                          onTap: (entry, additive) {
                                            controller.selectItem(
                                              selectionKey: entry.selectionKey,
                                              additive: additive,
                                            );
                                          },
                                          onDoubleTap: (entry) async {
                                            if (entry.isFolder) {
                                              await _guarded(
                                                () => controller.openFolder(
                                                  entry.id,
                                                ),
                                              );
                                            } else {
                                              _showInfoDialog(
                                                title: 'File info',
                                                lines: _fileInfoLines(
                                                  entry.file!,
                                                  state,
                                                ),
                                              );
                                            }
                                          },
                                          onContext: _showEntryContextMenu,
                                        ),
                                ),
                                if (state.isDragHovering)
                                  Container(
                                    color: const Color(0x331F1F1F),
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xCC111111),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0x66D11D2E),
                                        ),
                                      ),
                                      child: const Text(
                                        'Drop files to upload into current folder',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (state.isBusy)
                                  Container(
                                    color: const Color(0x44000000),
                                    alignment: Alignment.topCenter,
                                    child: const LinearProgressIndicator(
                                      minHeight: 2,
                                      color: AppColors.accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ExplorerState state, ExplorerEntry? selectedEntry) {
    final controller = ref.read(explorerControllerProvider.notifier);

    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141414), Color(0xFF0E0E0E)],
        ),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x33D11D2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x66D11D2E)),
            ),
            child: const Icon(Icons.folder_special, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Steel Explorer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              onChanged: controller.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search in current folder',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: AppColors.panelElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _createFolderDialog(),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Create folder'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _pickAndUpload,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              await _guarded(() => controller.refresh());
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: state.gridMode ? 'List view' : 'Grid view',
            onPressed: () => controller.setGridMode(!state.gridMode),
            icon: Icon(state.gridMode ? Icons.view_list : Icons.grid_view),
          ),
          IconButton(
            tooltip: 'Download selected',
            onPressed: selectedEntry?.isFolder == false
                ? () => _downloadFile(selectedEntry!.file!)
                : null,
            icon: const Icon(Icons.download_outlined),
          ),
          const SizedBox(width: 10),
          Text(
            state.selectedItemKeys.isEmpty
                ? 'No selection'
                : '${state.selectedItemKeys.length} selected',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCanvasContextMenu(Offset globalPosition) async {
    final action = await showMenu<_CanvasAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: const [
        PopupMenuItem(
          value: _CanvasAction.createFolder,
          child: Text('Create folder'),
        ),
        PopupMenuItem(
          value: _CanvasAction.uploadFile,
          child: Text('Upload file'),
        ),
        PopupMenuItem(value: _CanvasAction.refresh, child: Text('Refresh')),
      ],
    );

    if (action == null) {
      return;
    }

    switch (action) {
      case _CanvasAction.createFolder:
        await _createFolderDialog();
      case _CanvasAction.uploadFile:
        await _pickAndUpload();
      case _CanvasAction.refresh:
        await _guarded(
          () => ref.read(explorerControllerProvider.notifier).refresh(),
        );
    }
  }

  Future<void> _showFolderContextMenu(
    FolderNode folder,
    Offset globalPosition,
  ) async {
    final controller = ref.read(explorerControllerProvider.notifier);

    final action = await showMenu<_EntryAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        const PopupMenuItem(value: _EntryAction.open, child: Text('Open')),
        const PopupMenuItem(
          value: _EntryAction.createFolder,
          child: Text('Create subfolder'),
        ),
        const PopupMenuItem(
          value: _EntryAction.uploadFile,
          child: Text('Upload file'),
        ),
        if (!folder.isRoot)
          const PopupMenuItem(
            value: _EntryAction.rename,
            child: Text('Rename'),
          ),
        if (!folder.isRoot)
          const PopupMenuItem(
            value: _EntryAction.move,
            child: Text('Move to...'),
          ),
        if (!folder.isRoot)
          const PopupMenuItem(
            value: _EntryAction.delete,
            child: Text('Delete'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _EntryAction.copyPath,
          child: Text('Copy path'),
        ),
        const PopupMenuItem(value: _EntryAction.info, child: Text('Show info')),
      ],
    );

    if (action == null) {
      return;
    }

    switch (action) {
      case _EntryAction.open:
        await _guarded(() => controller.openFolder(folder.id));
      case _EntryAction.createFolder:
        await _createFolderDialog(parentId: folder.id);
      case _EntryAction.uploadFile:
        await _pickAndUpload();
      case _EntryAction.rename:
        final renamed = await _promptText(
          title: 'Rename folder',
          initialValue: folder.name,
          actionLabel: 'Rename',
        );
        if (renamed != null && renamed != folder.name) {
          await _guarded(
            () =>
                controller.renameFolder(folderId: folder.id, newName: renamed),
          );
          _showSuccess('Folder renamed');
        }
      case _EntryAction.move:
        final target = await _showMoveFolderDialog(folder);
        if (target != null) {
          await _guarded(
            () => controller.moveFolder(
              folderId: folder.id,
              targetParentId: target,
            ),
          );
          _showSuccess('Folder moved');
        }
      case _EntryAction.delete:
        final confirmed = await _confirm(
          title: 'Delete folder?',
          message:
              'Folder "${folder.name}" and all nested files/folders will be permanently deleted.',
          confirmLabel: 'Delete',
        );
        if (confirmed) {
          await _guarded(() => controller.deleteFolder(folder.id));
          _showSuccess('Folder deleted');
        }
      case _EntryAction.copyPath:
        await Clipboard.setData(ClipboardData(text: folder.path));
        _showSuccess('Path copied');
      case _EntryAction.info:
        _showInfoDialog(title: 'Folder info', lines: _folderInfoLines(folder));
      case _EntryAction.download:
      case _EntryAction.refresh:
    }
  }

  Future<void> _showEntryContextMenu(
    ExplorerEntry entry,
    Offset globalPosition,
  ) async {
    final controller = ref.read(explorerControllerProvider.notifier);

    final action = await showMenu<_EntryAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        const PopupMenuItem(value: _EntryAction.open, child: Text('Open')),
        const PopupMenuItem(value: _EntryAction.rename, child: Text('Rename')),
        const PopupMenuItem(
          value: _EntryAction.move,
          child: Text('Move to...'),
        ),
        if (!entry.isFolder)
          const PopupMenuItem(
            value: _EntryAction.download,
            child: Text('Download'),
          ),
        const PopupMenuItem(value: _EntryAction.delete, child: Text('Delete')),
        const PopupMenuItem(
          value: _EntryAction.refresh,
          child: Text('Refresh'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _EntryAction.copyPath,
          child: Text('Copy path'),
        ),
        const PopupMenuItem(value: _EntryAction.info, child: Text('Show info')),
      ],
    );

    if (action == null) {
      return;
    }

    switch (action) {
      case _EntryAction.open:
        if (entry.isFolder) {
          await _guarded(() => controller.openFolder(entry.id));
        } else {
          _showInfoDialog(
            title: 'File info',
            lines: _fileInfoLines(
              entry.file!,
              ref.read(explorerControllerProvider),
            ),
          );
        }
      case _EntryAction.rename:
        final renamed = await _promptText(
          title: entry.isFolder ? 'Rename folder' : 'Rename file',
          initialValue: entry.name,
          actionLabel: 'Rename',
        );
        if (renamed != null && renamed != entry.name) {
          if (entry.isFolder) {
            await _guarded(
              () =>
                  controller.renameFolder(folderId: entry.id, newName: renamed),
            );
            _showSuccess('Folder renamed');
          } else {
            await _guarded(
              () => controller.renameFile(fileId: entry.id, newName: renamed),
            );
            _showSuccess('File renamed');
          }
        }
      case _EntryAction.move:
        if (entry.isFolder) {
          final folder = entry.folder!;
          final target = await _showMoveFolderDialog(folder);
          if (target != null) {
            await _guarded(
              () => controller.moveFolder(
                folderId: folder.id,
                targetParentId: target,
              ),
            );
            _showSuccess('Folder moved');
          }
        } else {
          final file = entry.file!;
          final target = await _showMoveFileDialog(file);
          if (target != null) {
            await _guarded(
              () =>
                  controller.moveFile(fileId: file.id, targetFolderId: target),
            );
            _showSuccess('File moved');
          }
        }
      case _EntryAction.download:
        if (!entry.isFolder) {
          await _downloadFile(entry.file!);
        }
      case _EntryAction.delete:
        final confirmed = await _confirm(
          title: entry.isFolder ? 'Delete folder?' : 'Delete file?',
          message: entry.isFolder
              ? 'Folder "${entry.name}" and all nested content will be deleted.'
              : 'File "${entry.name}" will be deleted permanently.',
          confirmLabel: 'Delete',
        );
        if (confirmed) {
          if (entry.isFolder) {
            await _guarded(() => controller.deleteFolder(entry.id));
            _showSuccess('Folder deleted');
          } else {
            await _guarded(() => controller.deleteFile(entry.file!));
            _showSuccess('File deleted');
          }
        }
      case _EntryAction.refresh:
        await _guarded(() => controller.refresh());
      case _EntryAction.copyPath:
        final state = ref.read(explorerControllerProvider);
        final path = _entryPath(entry, state);
        await Clipboard.setData(ClipboardData(text: path));
        _showSuccess('Path copied');
      case _EntryAction.info:
        if (entry.isFolder) {
          _showInfoDialog(
            title: 'Folder info',
            lines: _folderInfoLines(entry.folder!),
          );
        } else {
          _showInfoDialog(
            title: 'File info',
            lines: _fileInfoLines(
              entry.file!,
              ref.read(explorerControllerProvider),
            ),
          );
        }
      case _EntryAction.createFolder:
      case _EntryAction.uploadFile:
    }
  }

  Future<void> _createFolderDialog({String? parentId}) async {
    final name = await _promptText(
      title: 'Create folder',
      initialValue: '',
      actionLabel: 'Create',
      hintText: 'Folder name',
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    await _guarded(() async {
      await ref
          .read(explorerControllerProvider.notifier)
          .createFolder(name, parentId: parentId);
      _showSuccess('Folder created');
    });
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      dialogTitle: 'Select file(s) to upload',
    );

    final paths =
        result?.paths.whereType<String>().toList() ?? const <String>[];
    if (paths.isEmpty) {
      return;
    }

    await _guarded(() async {
      await ref.read(explorerControllerProvider.notifier).uploadFiles(paths);
      _showSuccess('Uploaded ${paths.length} file(s)');
    });
  }

  Future<void> _downloadFile(FileItem file) async {
    await _guarded(() async {
      final location = await getSaveLocation(suggestedName: file.name);
      if (location == null || location.path.trim().isEmpty) {
        return;
      }

      final bytes = await ref
          .read(explorerControllerProvider.notifier)
          .downloadFile(file.storagePath);
      final output = File(location.path);
      await output.writeAsBytes(bytes, flush: true);
      _showSuccess('File saved: ${output.path}');
    });
  }

  Future<void> _handleInternalDrop(
    ExplorerDragPayload payload,
    String targetFolderId,
  ) async {
    final controller = ref.read(explorerControllerProvider.notifier);

    await _guarded(() async {
      if (payload.isFolder) {
        await controller.moveFolder(
          folderId: payload.id,
          targetParentId: targetFolderId,
        );
        _showSuccess('Folder moved');
      } else {
        await controller.moveFile(
          fileId: payload.id,
          targetFolderId: targetFolderId,
        );
        _showSuccess('File moved');
      }
    });
  }

  Future<String?> _showMoveFileDialog(FileItem file) async {
    final state = ref.read(explorerControllerProvider);
    final folders = state.folders.sortedBy((item) => item.path.toLowerCase());
    String? selected = folders
        .firstWhereOrNull((item) => item.id != file.folderId)
        ?.id;

    if (selected == null) {
      _showError('No destination folders available.');
      return null;
    }

    return showDialog<String?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.panel,
              title: const Text('Move file'),
              content: DropdownButtonFormField<String>(
                initialValue: selected,
                items: folders
                    .where((folder) => folder.id != file.folderId)
                    .map(
                      (folder) => DropdownMenuItem(
                        value: folder.id,
                        child: Text(folder.path),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selected = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.of(context).pop(selected),
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showMoveFolderDialog(FolderNode folder) async {
    final controller = ref.read(explorerControllerProvider.notifier);
    final state = ref.read(explorerControllerProvider);

    final blocked = controller.collectDescendantFolderIds(folder.id)
      ..add(folder.id);

    final candidates = state.folders
        .where((candidate) => !blocked.contains(candidate.id))
        .sortedBy((candidate) => candidate.path.toLowerCase());

    if (candidates.isEmpty) {
      _showError('No valid destination folder available.');
      return null;
    }

    String? selected = candidates.first.id;

    return showDialog<String?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.panel,
              title: const Text('Move folder'),
              content: DropdownButtonFormField<String?>(
                initialValue: selected,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Move to root'),
                  ),
                  ...candidates.map(
                    (candidate) => DropdownMenuItem<String?>(
                      value: candidate.id,
                      child: Text(candidate.path),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selected = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: const Text('Move'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _promptText({
    required String title,
    required String initialValue,
    required String actionLabel,
    String? hintText,
  }) async {
    final controller = TextEditingController(text: initialValue);

    return showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: hintText),
            onSubmitted: (_) =>
                Navigator.of(context).pop(controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _showInfoDialog({required String title, required List<String> lines}) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(title),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(line),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  List<String> _folderInfoLines(FolderNode folder) {
    return [
      'Name: ${folder.name}',
      'Path: ${folder.path}',
      'Created: ${folder.createdAt.toExplorerDate()}',
      'Updated: ${folder.updatedAt.toExplorerDate()}',
      'ID: ${folder.id}',
    ];
  }

  List<String> _fileInfoLines(FileItem file, ExplorerState state) {
    final folderPath =
        state.folders
            .firstWhereOrNull((folder) => folder.id == file.folderId)
            ?.path ??
        '(unknown folder)';

    return [
      'Name: ${file.name}',
      'Type: ${file.normalizedExtension.isEmpty ? 'unknown' : file.normalizedExtension}',
      'Size: ${formatBytes(file.sizeBytes)}',
      'Folder: $folderPath',
      'Storage path: ${file.storagePath}',
      'Uploaded: ${file.createdAt.toExplorerDate()}',
      'Updated: ${file.updatedAt.toExplorerDate()}',
      'ID: ${file.id}',
    ];
  }

  String _entryPath(ExplorerEntry entry, ExplorerState state) {
    if (entry.isFolder) {
      return entry.folder!.path;
    }

    final folderPath =
        state.folders
            .firstWhereOrNull((folder) => folder.id == entry.file!.folderId)
            ?.path ??
        '';
    return folderPath.isEmpty
        ? entry.file!.name
        : '$folderPath/${entry.file!.name}';
  }

  ExplorerEntry? _singleSelectedEntry(
    List<ExplorerEntry> entries,
    Set<String> selected,
  ) {
    if (selected.length != 1) {
      return null;
    }
    final key = selected.first;
    return entries.firstWhereOrNull((entry) => entry.selectionKey == key);
  }

  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } on AppException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    }
  }

  void _showSuccess(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF173A2A),
        content: Text(message),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF421920),
        content: Text(message),
      ),
    );
  }
}
