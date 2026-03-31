import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/date_formatters.dart';
import '../../core/utils/file_formatters.dart';
import '../../models/explorer_drag_payload.dart';
import '../../models/explorer_entry.dart';

typedef EntryTapCallback = void Function(ExplorerEntry entry, bool additive);
typedef EntryCallback = void Function(ExplorerEntry entry);
typedef EntryContextCallback =
    void Function(ExplorerEntry entry, Offset position);

class ExplorerItemsView extends StatelessWidget {
  const ExplorerItemsView({
    super.key,
    required this.entries,
    required this.gridMode,
    required this.selectedKeys,
    required this.onTap,
    required this.onDoubleTap,
    required this.onContext,
  });

  final List<ExplorerEntry> entries;
  final bool gridMode;
  final Set<String> selectedKeys;
  final EntryTapCallback onTap;
  final EntryCallback onDoubleTap;
  final EntryContextCallback onContext;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'Папка пуста',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    if (gridMode) {
      return GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _ExplorerEntryCard(
            entry: entry,
            selected: selectedKeys.contains(entry.selectionKey),
            compact: false,
            onTap: (additive) => onTap(entry, additive),
            onDoubleTap: () => onDoubleTap(entry),
            onContext: (position) => onContext(entry, position),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _ExplorerEntryCard(
            entry: entry,
            selected: selectedKeys.contains(entry.selectionKey),
            compact: true,
            onTap: (additive) => onTap(entry, additive),
            onDoubleTap: () => onDoubleTap(entry),
            onContext: (position) => onContext(entry, position),
          ),
        );
      },
    );
  }
}

class _ExplorerEntryCard extends StatefulWidget {
  const _ExplorerEntryCard({
    required this.entry,
    required this.selected,
    required this.compact,
    required this.onTap,
    required this.onDoubleTap,
    required this.onContext,
  });

  final ExplorerEntry entry;
  final bool selected;
  final bool compact;
  final ValueChanged<bool> onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<Offset> onContext;

  @override
  State<_ExplorerEntryCard> createState() => _ExplorerEntryCardState();
}

class _ExplorerEntryCardState extends State<_ExplorerEntryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final icon = widget.entry.isFolder
        ? Icons.folder
        : iconForExtension(widget.entry.file!.normalizedExtension);

    final subtitle = widget.entry.isFolder
        ? widget.entry.folder!.path
        : '${formatBytes(widget.entry.file!.sizeBytes)}  |  ${widget.entry.file!.updatedAt.toExplorerDate()}';

    final modified = _isAdditiveModifierPressed();

    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) => widget.onContext(details.globalPosition),
      onDoubleTap: widget.onDoubleTap,
      onTap: () => widget.onTap(modified),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0x26D11D2E)
                : _hovered
                ? const Color(0x141F1F1F)
                : AppColors.panel,
            borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
            border: Border.all(
              color: widget.selected
                  ? const Color(0x66D11D2E)
                  : _hovered
                  ? const Color(0x33404040)
                  : AppColors.border,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.compact ? 12 : 16),
            child: widget.compact
                ? Row(
                    children: [
                      Icon(icon, color: AppColors.accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.entry.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: AppColors.accent, size: 30),
                      const Spacer(),
                      Text(
                        widget.entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    return Draggable<ExplorerDragPayload>(
      data: ExplorerDragPayload(
        id: widget.entry.id,
        isFolder: widget.entry.isFolder,
      ),
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints.tight(
            widget.compact ? const Size(280, 60) : const Size(190, 120),
          ),
          child: Opacity(opacity: 0.85, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: card),
      child: card,
    );
  }
}

bool _isAdditiveModifierPressed() {
  final pressed = HardwareKeyboard.instance.logicalKeysPressed;
  return pressed.contains(LogicalKeyboardKey.controlLeft) ||
      pressed.contains(LogicalKeyboardKey.controlRight) ||
      pressed.contains(LogicalKeyboardKey.metaLeft) ||
      pressed.contains(LogicalKeyboardKey.metaRight);
}
