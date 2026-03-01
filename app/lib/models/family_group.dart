import 'package:json_annotation/json_annotation.dart';

part 'family_group.g.dart';

/// A family group — the top-level unit that contains members,
/// categories, transactions, and shared budget settings.
@JsonSerializable()
class FamilyGroup {
  final String id;
  final String name;
  final String? avatarInitial;
  final String defaultCurrency;
  final String regionFormat;
  final bool expenseAlertsEnabled;
  final double monthlyBudgetLimit;
  final String createdByUserId;
  final DateTime createdAt;

  const FamilyGroup({
    required this.id,
    required this.name,
    this.avatarInitial,
    this.defaultCurrency = 'INR',
    this.regionFormat = 'IN',
    this.expenseAlertsEnabled = true,
    required this.monthlyBudgetLimit,
    required this.createdByUserId,
    required this.createdAt,
  });

  factory FamilyGroup.fromJson(Map<String, dynamic> json) =>
      _$FamilyGroupFromJson(json);

  Map<String, dynamic> toJson() => _$FamilyGroupToJson(this);

  /// Format the budget limit for display (e.g., "₹50,000").
  String get formattedBudgetLimit =>
      '₹${monthlyBudgetLimit.toStringAsFixed(0)}';
}
