// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FamilyGroup _$FamilyGroupFromJson(Map<String, dynamic> json) => FamilyGroup(
  id: json['id'] as String,
  name: json['name'] as String,
  avatarInitial: json['avatarInitial'] as String?,
  defaultCurrency: json['defaultCurrency'] as String? ?? 'INR',
  regionFormat: json['regionFormat'] as String? ?? 'IN',
  expenseAlertsEnabled: json['expenseAlertsEnabled'] as bool? ?? true,
  monthlyBudgetLimit: (json['monthlyBudgetLimit'] as num).toDouble(),
  createdByUserId: json['createdByUserId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$FamilyGroupToJson(FamilyGroup instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatarInitial': instance.avatarInitial,
      'defaultCurrency': instance.defaultCurrency,
      'regionFormat': instance.regionFormat,
      'expenseAlertsEnabled': instance.expenseAlertsEnabled,
      'monthlyBudgetLimit': instance.monthlyBudgetLimit,
      'createdByUserId': instance.createdByUserId,
      'createdAt': instance.createdAt.toIso8601String(),
    };
