import 'package:flutter/material.dart';

/// Renders a category icon from its stored string.
///
/// Category icons are stored either as an emoji (e.g. `🛒`) or as a Material
/// icon name in snake_case (e.g. `shopping_cart`). This widget maps the latter
/// to the matching [Icons] glyph and falls back to rendering the raw string
/// (emoji) as text so both conventions display correctly.
class CategoryIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color? color;

  const CategoryIcon({
    super.key,
    required this.icon,
    this.size = 22,
    this.color,
  });

  static const Map<String, IconData> _materialIcons = {
    'shopping_cart': Icons.shopping_cart,
    'shopping_bag': Icons.shopping_bag,
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'local_mall': Icons.local_mall,
    'local_gas_station': Icons.local_gas_station,
    'power': Icons.power,
    'local_hospital': Icons.local_hospital,
    'medical_services': Icons.medical_services,
    'movie': Icons.movie,
    'flight': Icons.flight,
    'home': Icons.home,
    'payments': Icons.payments,
    'receipt_long': Icons.receipt_long,
    'trending_up': Icons.trending_up,
    'sports_esports': Icons.sports_esports,
    'category': Icons.category,
  };

  @override
  Widget build(BuildContext context) {
    final material = _materialIcons[icon];
    if (material != null) {
      return Icon(material, size: size, color: color);
    }
    // Emoji (or any unknown string) — render as-is.
    return Text(icon, style: TextStyle(fontSize: size * 0.9));
  }
}
