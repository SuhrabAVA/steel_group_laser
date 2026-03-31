import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/explorer_drag_payload.dart';
import '../../models/folder_node.dart';

typedef FolderContextCallback =
    void Function(FolderNode folder, Offset position);

typedef FolderDropCallback =
    void Function(ExplorerDragPayload payload, FolderNode target);

class SidebarFolderTree extends StatelessWidget {
  const SidebarFolderTree({
    super.key,
    required this.folders,
    required this.currentFolderId,
    required this.onFolderTap,
    required this.onFolderContext,
    required this.onFolderDrop,
  });

  final List<FolderNode> folders;
  final String? currentFolderId;
  final ValueChanged<String> onFolderTap;
  final FolderContextCallback onFolderContext;
  final FolderDropCallback onFolderDrop;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: const [
                Icon(Icons.account_tree_outlined, color: AppColors.accent),
                SizedBox(width: 10),
                Text(
                  'Папки',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return _FolderTreeRow(
                  folder: folder,
                  selected: folder.id == currentFolderId,
                  onTap: () => onFolderTap(folder.id),
                  onContext: (position) => onFolderContext(folder, position),
                  onDrop: (payload) => onFolderDrop(payload, folder),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderTreeRow extends StatefulWidget {
  const _FolderTreeRow({
    required this.folder,
    required this.selected,
    required this.onTap,
    required this.onContext,
    required this.onDrop,
  });

  final FolderNode folder;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContext;
  final ValueChanged<ExplorerDragPayload> onDrop;

  @override
  State<_FolderTreeRow> createState() => _FolderTreeRowState();
}

class _FolderTreeRowState extends State<_FolderTreeRow> {
  bool _dragHover = false;

  @override
  Widget build(BuildContext context) {
    final leftIndent = 12.0 + (widget.folder.depth * 18);

    return DragTarget<ExplorerDragPayload>(
      onWillAcceptWithDetails: (details) {
        final payload = details.data;
        final canAccept = payload.id != widget.folder.id;
        setState(() {
          _dragHover = canAccept;
        });
        return canAccept;
      },
      onLeave: (_) {
        setState(() {
          _dragHover = false;
        });
      },
      onAcceptWithDetails: (details) {
        setState(() {
          _dragHover = false;
        });
        widget.onDrop(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onSecondaryTapDown: (details) {
            widget.onContext(details.globalPosition);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: EdgeInsets.fromLTRB(leftIndent, 9, 10, 9),
            decoration: BoxDecoration(
              color: _dragHover
                  ? const Color(0x33D11D2E)
                  : widget.selected
                  ? const Color(0x22D11D2E)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _dragHover
                    ? const Color(0x66D11D2E)
                    : widget.selected
                    ? const Color(0x44D11D2E)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.folder.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.selected
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: widget.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
