import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

class TagColors {
  static final TagColors instance = TagColors._();
  TagColors._();

  final Map<String, Color> _map = {
    for (final e in AppColors.defaultTagColors.entries) e.key: Color(e.value),
  };

  final List<Color> palette = const [
    Color(0xFF7C6CF0),
    Color(0xFF22C55E),
    Color(0xFFEC4899),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF14B8A6),
    Color(0xFFEF4444),
    Color(0xFF94A3B8),
  ];

  Color of(String tag) => _map[tag] ?? AppColors.primary;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    for (final key in AppColors.defaultTagColors.keys) {
      final v = p.getInt('tag_color_$key');
      if (v != null) _map[key] = Color(v);
    }
  }

  Future<void> set(String tag, Color color) async {
    _map[tag] = color;
    final p = await SharedPreferences.getInstance();
    await p.setInt('tag_color_$tag', color.value);
  }
}
