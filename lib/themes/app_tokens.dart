/// Design tokens — spacing scale and corner radius scale.
///
/// Use these instead of magic numbers so the design system stays consistent.
///
/// Usage:
///   padding: const EdgeInsets.all(Insets.lg)
///   borderRadius: BorderRadius.circular(Radii.md)
class Insets {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

class Radii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double pill = 999.0;
}
