import '../models/category.dart';
import '../widgets/category_icon.dart';

/// Fallback display names for the seeded/legacy category ids (`cat_001`…).
///
/// Used only when a transaction's category cannot be resolved against the
/// family's real [Category] list (categories still loading, offline/mock data,
/// or a stale id). These match the backend seed data and the mock sample data
/// so the Dashboard and the Feed always agree.
const Map<String, String> fallbackCategoryNames = {
  'cat_001': 'Groceries',
  'cat_002': 'Dining',
  'cat_003': 'Transport',
  'cat_004': 'Housing',
  'cat_005': 'Bills',
  'cat_006': 'Health',
  'cat_007': 'Entertainment',
  'cat_008': 'Shopping',
};

/// Fallback icons for the same seeded ids, as strings accepted by
/// [CategoryIcon] (emoji or Material icon names).
const Map<String, String> fallbackCategoryIcons = {
  'cat_001': '🛒',
  'cat_002': '🍽️',
  'cat_003': '🚗',
  'cat_004': '🏠',
  'cat_005': '📄',
  'cat_006': '💊',
  'cat_007': '🎬',
  'cat_008': '🛍️',
};

/// Resolve the display name for a transaction's category, preferring the
/// family's real [Category] and falling back to the shared seed map.
String resolveCategoryName(String? categoryId, List<Category> categories) {
  if (categoryId == null || categoryId.isEmpty || categoryId == 'uncategorized') {
    return 'Uncategorized';
  }
  for (final category in categories) {
    if (category.id == categoryId) return category.name;
  }
  return fallbackCategoryNames[categoryId] ?? 'Other';
}

/// Resolve the icon for a transaction's category: the real [Category] icon,
/// else the shared seed map, else an empty string (callers render a generic
/// placeholder for unknown categories).
String resolveCategoryIcon(String? categoryId, List<Category> categories) {
  if (categoryId == null || categoryId.isEmpty || categoryId == 'uncategorized') {
    return '';
  }
  for (final category in categories) {
    if (category.id == categoryId) return category.icon;
  }
  return fallbackCategoryIcons[categoryId] ?? '';
}