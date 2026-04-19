import 'package:flutter/material.dart';

/// Visual themes the user can pick from. All variants are dark surfaces —
/// the app's UI components rely on light text — they only differ in
/// background gradient and accent glow tint.
enum ThemeVariant {
  emerald('Emerald', 'Default · green & cyan'),
  midnight('Midnight', 'Pure black with subtle haze'),
  sunset('Sunset', 'Warm orange & magenta');

  const ThemeVariant(this.label, this.description);

  final String label;
  final String description;

  /// Background base gradient (3 stops) painted under the glow circles.
  List<Color> get backgroundGradient => switch (this) {
        ThemeVariant.emerald => const [
            Color(0xFF07070D),
            Color(0xFF0B0B16),
            Color(0xFF070712),
          ],
        ThemeVariant.midnight => const [
            Color(0xFF000000),
            Color(0xFF050507),
            Color(0xFF000000),
          ],
        ThemeVariant.sunset => const [
            Color(0xFF120808),
            Color(0xFF1A0A14),
            Color(0xFF0E0606),
          ],
      };

  /// Three glow circles (color, alpha) used by the gradient background.
  List<Color> get glowColors => switch (this) {
        ThemeVariant.emerald => const [
            Color(0xFF22C55E),
            Color(0xFF67E8F9),
            Color(0xFF8B5CF6),
          ],
        ThemeVariant.midnight => const [
            Color(0xFF1F2937),
            Color(0xFF374151),
            Color(0xFF4B5563),
          ],
        ThemeVariant.sunset => const [
            Color(0xFFFB923C),
            Color(0xFFEC4899),
            Color(0xFFF472B6),
          ],
      };

  /// Two-stop accent gradient used for the small swatch preview chips.
  List<Color> get previewGradient => switch (this) {
        ThemeVariant.emerald => const [
            Color(0xFF22C55E),
            Color(0xFF06B6D4),
          ],
        ThemeVariant.midnight => const [
            Color(0xFF1F2937),
            Color(0xFF000000),
          ],
        ThemeVariant.sunset => const [
            Color(0xFFFB923C),
            Color(0xFFEC4899),
          ],
      };

  static ThemeVariant fromName(String? name) {
    if (name == null) return ThemeVariant.emerald;
    return ThemeVariant.values.firstWhere(
      (v) => v.name == name,
      orElse: () => ThemeVariant.emerald,
    );
  }
}
