// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
  id: json['id'] as String,
  familyGroupId: json['familyGroupId'] as String,
  name: json['name'] as String,
  icon: json['icon'] as String,
  budgetLimit: (json['budgetLimit'] as num).toDouble(),
  color: json['color'] as String,
  sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
  'id': instance.id,
  'familyGroupId': instance.familyGroupId,
  'name': instance.name,
  'icon': instance.icon,
  'budgetLimit': instance.budgetLimit,
  'color': instance.color,
  'sortOrder': instance.sortOrder,
};
