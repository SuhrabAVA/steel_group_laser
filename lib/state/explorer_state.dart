import '../models/file_item.dart';
import '../models/folder_node.dart';

class ExplorerState {
  const ExplorerState({
    required this.folders,
    required this.files,
    required this.selectedItemKeys,
    required this.isLoading,
    required this.isBusy,
    required this.isDragHovering,
    required this.gridMode,
    required this.searchQuery,
    required this.initialized,
    this.currentFolderId,
    this.errorMessage,
  });

  const ExplorerState.initial()
    : folders = const [],
      files = const [],
      selectedItemKeys = const {},
      isLoading = false,
      isBusy = false,
      isDragHovering = false,
      gridMode = false,
      searchQuery = '',
      initialized = false,
      currentFolderId = null,
      errorMessage = null;

  final List<FolderNode> folders;
  final List<FileItem> files;
  final Set<String> selectedItemKeys;
  final bool isLoading;
  final bool isBusy;
  final bool isDragHovering;
  final bool gridMode;
  final bool initialized;
  final String searchQuery;
  final String? currentFolderId;
  final String? errorMessage;

  ExplorerState copyWith({
    List<FolderNode>? folders,
    List<FileItem>? files,
    Set<String>? selectedItemKeys,
    bool? isLoading,
    bool? isBusy,
    bool? isDragHovering,
    bool? gridMode,
    bool? initialized,
    String? searchQuery,
    String? currentFolderId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExplorerState(
      folders: folders ?? this.folders,
      files: files ?? this.files,
      selectedItemKeys: selectedItemKeys ?? this.selectedItemKeys,
      isLoading: isLoading ?? this.isLoading,
      isBusy: isBusy ?? this.isBusy,
      isDragHovering: isDragHovering ?? this.isDragHovering,
      gridMode: gridMode ?? this.gridMode,
      initialized: initialized ?? this.initialized,
      searchQuery: searchQuery ?? this.searchQuery,
      currentFolderId: currentFolderId ?? this.currentFolderId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
