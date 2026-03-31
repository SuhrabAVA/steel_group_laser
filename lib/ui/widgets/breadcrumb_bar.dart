import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/folder_node.dart';

class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({
    super.key,
    required this.breadcrumb,
    required this.onTap,
  });

  final List<FolderNode> breadcrumb;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (breadcrumb.isEmpty) {
      return const Text(
        'Папка не выбрана',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < breadcrumb.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onTap(breadcrumb[i].id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  breadcrumb[i].name,
                  style: TextStyle(
                    color: i == breadcrumb.length - 1
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontWeight: i == breadcrumb.length - 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
