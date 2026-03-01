import 'package:json_annotation/json_annotation.dart';

part 'category.g.dart';

/// A budget category within a family group (e.g., Groceries, Dining, Transport).
@JsonSerializable()
class Category {
  final String id;
  final String familyGroupId;
  final String name;
  final String icon;
  final double budgetLimit;
  final String color;
  final int sortOrder;

  const Category({
    required this.id,
    required this.familyGroupId,
    required this.name,
    required this.icon,
    required this.budgetLimit,
    required this.color,
    this.sortOrder = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryToJson(this);

  /// Format the budget limit for display (e.g., "₹5,000").
  String get formattedBudgetLimit => '₹${budgetLimit.toStringAsFixed(0)}';
}
