import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category_service.dart';
import '../models/category.dart';
import 'service_providers.dart';

class CategoryState {
  final List<Category> categories;
  final bool isLoading;
  final String? error;

  const CategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  CategoryState copyWith({
    List<Category>? categories,
    bool? isLoading,
    String? error,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CategoryNotifier extends Notifier<CategoryState> {
  late final CategoryService _service;

  @override
  CategoryState build() {
    _service = ref.watch(categoryServiceProvider);
    return const CategoryState();
  }

  Future<void> loadCategories(String familyGroupId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final categories = await _service.getCategories(familyGroupId);
      state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> createCategory(String familyGroupId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final category = await _service.createCategory(familyGroupId, data);
      state = state.copyWith(
        categories: [...state.categories, category],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> updateCategory(String familyGroupId, String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updated = await _service.updateCategory(familyGroupId, id, data);
      state = state.copyWith(
        categories: state.categories.map((c) => c.id == id ? updated : c).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> deleteCategory(String familyGroupId, String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.deleteCategory(familyGroupId, id);
      state = state.copyWith(
        categories: state.categories.where((c) => c.id != id).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final categoryProvider = NotifierProvider<CategoryNotifier, CategoryState>(
  CategoryNotifier.new,
);
