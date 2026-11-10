import 'package:flutter/material.dart';

/// Bundled fonts only (see LICENSES/fonts). No fallback family is given for Hebrew, so if
/// Ezra SIL failed to load the screenshots would show it rather than hide it behind a system font.
class Fonts {
  static const hebrew = 'EzraSIL';
  static const greek = 'Gentium';
  static const latin = 'Gentium';
}

class TextStyles {
  static TextStyle hebrew(double size) => TextStyle(
    fontFamily: Fonts.hebrew,
    fontSize: size,
    height: 1.9,
    color: Colors.black,
  );
  static TextStyle greek(double size) => TextStyle(
    fontFamily: Fonts.greek,
    fontSize: size,
    height: 1.5,
    color: Colors.black,
  );
  static TextStyle english(double size) => TextStyle(
    fontFamily: Fonts.latin,
    fontSize: size,
    height: 1.5,
    color: Colors.black,
  );

  static TextStyle forLanguage(String lang, double size) => switch (lang) {
    'hbo' => hebrew(size * 1.35),
    'grc' => greek(size * 1.05),
    _ => english(size),
  };
}
