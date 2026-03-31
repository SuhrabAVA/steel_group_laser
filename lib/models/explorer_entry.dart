import 'file_item.dart';
import 'folder_node.dart';

enum ExplorerEntryType { folder, file }

class ExplorerEntry {
  const ExplorerEntry.folder(this.folder)
    : file = null,
      type = ExplorerEntryType.folder;

  const ExplorerEntry.file(this.file)
    : folder = null,
      type = ExplorerEntryType.file;

  final ExplorerEntryType type;
  final FolderNode? folder;
  final FileItem? file;

  bool get isFolder => type == ExplorerEntryType.folder;

  String get id {
    if (isFolder) {
      return folder!.id;
    }
    return file!.id;
  }

  String get selectionKey => '${isFolder ? 'folder' : 'file'}:$id';

  String get name => isFolder ? folder!.name : file!.name;
}
