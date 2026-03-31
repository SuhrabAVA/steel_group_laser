import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

String formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)} GB';
}

String extensionFromName(String fileName) {
  final extension = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  return extension;
}

IconData iconForExtension(String extension) {
  switch (extension.toLowerCase()) {
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
    case 'bmp':
    case 'svg':
      return Icons.image_outlined;
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'doc':
    case 'docx':
    case 'txt':
    case 'rtf':
      return Icons.description_outlined;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Icons.table_chart_outlined;
    case 'dwg':
    case 'dxf':
    case 'stp':
    case 'step':
      return Icons.precision_manufacturing_outlined;
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
      return Icons.archive_outlined;
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
      return Icons.movie_outlined;
    case 'mp3':
    case 'wav':
    case 'ogg':
      return Icons.audiotrack_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}
