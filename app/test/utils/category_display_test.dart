import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/models/category.dart';
import 'package:budgetly/utils/category_display.dart';

void main() {
  const seedIds = [
    'cat_001',
    'cat_002',
    'cat_003',
    'cat_004',
    'cat_005',
    'cat_006',
    'cat_007',
    'cat_008',
  ];

  Category category(String id, {String? name, String? icon}) => Category(
    id: id,
    familyGroupId: 'family_001',
    name: name ?? 'Real $id',
    icon: icon ?? '🛒',
    budgetLimit: 1000,
    color: '#000000',
  );

  group('fallbackCategoryNames', () {
    test('covers every seeded id with the seed names', () {
      for (final id in seedIds) {
        expect(fallbackCategoryNames, contains(id));
      }
      // Issue #21 regression guard: the Dashboard and Feed previously used
      // different names for the same category.
      expect(fallbackCategoryNames['cat_001'], 'Groceries');
      expect(fallbackCategoryNames['cat_004'], 'Housing');
      expect(fallbackCategoryNames['cat_007'], 'Entertainment');
      expect(
        fallbackCategoryNames.values,
        isNot(containsAll(['Household', 'Home', 'Leisure'])),
      );
    });
  });

  group('fallbackCategoryIcons', () {
    test('covers every seeded id', () {
      for (final id in seedIds) {
        expect(fallbackCategoryIcons, contains(id));
      }
    });
  });

  group('resolveCategoryName', () {
    test('prefers the real Category from the provider', () {
      final categories = [category('cat_001', name: 'Real Groceries')];
      expect(resolveCategoryName('cat_001', categories), 'Real Groceries');
    });

    test('falls back to the shared seed map when categories are unknown', () {
      expect(resolveCategoryName('cat_001', const []), 'Groceries');
      expect(resolveCategoryName('cat_007', const []), 'Entertainment');
    });

    test('treats null/empty/uncategorized as Uncategorized', () {
      expect(resolveCategoryName(null, const []), 'Uncategorized');
      expect(resolveCategoryName('', const []), 'Uncategorized');
      expect(resolveCategoryName('uncategorized', const []), 'Uncategorized');
    });

    test('uses Other for ids neither in the provider nor the seed map', () {
      expect(resolveCategoryName('unknown_id', const []), 'Other');
    });
  });

  group('resolveCategoryIcon', () {
    test('prefers the real Category icon from the provider', () {
      final categories = [category('cat_001', icon: '🏠')];
      expect(resolveCategoryIcon('cat_001', categories), '🏠');
    });

    test('falls back to the shared seed map when categories are unknown', () {
      expect(resolveCategoryIcon('cat_001', const []), '🛒');
      expect(resolveCategoryIcon('cat_004', const []), '🏠');
    });

    test('returns empty for null/empty/uncategorized', () {
      expect(resolveCategoryIcon(null, const []), '');
      expect(resolveCategoryIcon('', const []), '');
      expect(resolveCategoryIcon('uncategorized', const []), '');
    });

    test('returns empty for ids neither in the provider nor the seed map', () {
      expect(resolveCategoryIcon('unknown_id', const []), '');
    });
  });
}