import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../models/category.dart';
import 'category_icon.dart';

/// Reusable category chooser for a modal bottom sheet.
///
/// Pops the sheet before invoking [onSelected]; `null` means uncategorized.
class CategoryPickerSheet extends StatelessWidget {
  final List<Category> categories;

  /// Id of the currently selected category, or null for uncategorized.
  final String? selectedCategoryId;

  final ValueChanged<Category?> onSelected;

  const CategoryPickerSheet({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection =
        selectedCategoryId != null && selectedCategoryId!.isNotEmpty;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'Category',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textMain,
              ),
            ),
          ),
          ListTile(
            key: const Key('category-option-none'),
            leading: Icon(
              Icons.label_off_outlined,
              color: context.colors.textDim,
            ),
            title: Text(
              'Uncategorized',
              style: GoogleFonts.inter(color: context.colors.textMain),
            ),
            trailing: hasSelection
                ? null
                : Icon(Icons.check, color: context.colors.primary),
            onTap: () {
              Navigator.pop(context);
              onSelected(null);
            },
          ),
          for (final category in categories)
            ListTile(
              key: Key('category-option-${category.id}'),
              leading: CategoryIcon(
                icon: category.icon,
                size: 20,
                color: context.colors.textMain,
              ),
              title: Text(
                category.name,
                style: GoogleFonts.inter(color: context.colors.textMain),
              ),
              trailing: category.id == selectedCategoryId
                  ? Icon(Icons.check, color: context.colors.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                onSelected(category);
              },
            ),
        ],
      ),
    );
  }
}
