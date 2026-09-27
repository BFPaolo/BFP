import 'package:flutter/material.dart';

enum ReaderThemeMode {
  light('Chiaro', Color(0xFFFFFFFF), Color(0xFF1B1B1B)),
  sepia('Seppia', Color(0xFFF4ECD8), Color(0xFF5B4636)),
  dark('Scuro', Color(0xFF121212), Color(0xFFE0E0E0)),
  black('Nero (AMOLED)', Color(0xFF000000), Color(0xFFBDBDBD));

  const ReaderThemeMode(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;
}

enum ReaderFontFamily {
  publisher('Editore', null),
  serif('Serif', 'Georgia, "Times New Roman", serif'),
  sans('Sans', 'Roboto, "Helvetica Neue", Arial, sans-serif'),
  mono('Mono', '"Roboto Mono", Menlo, monospace');

  const ReaderFontFamily(this.label, this.css);

  final String label;

  /// `null` = mantieni il font definito dal libro.
  final String? css;
}

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.5,
    this.theme = ReaderThemeMode.light,
    this.fontFamily = ReaderFontFamily.publisher,
    this.scrolled = false,
  });

  final int fontSize;
  final double lineHeight;
  final ReaderThemeMode theme;
  final ReaderFontFamily fontFamily;

  /// `true` = scorrimento continuo, `false` = impaginato.
  final bool scrolled;

  ReaderSettings copyWith({
    int? fontSize,
    double? lineHeight,
    ReaderThemeMode? theme,
    ReaderFontFamily? fontFamily,
    bool? scrolled,
  }) => ReaderSettings(
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    theme: theme ?? this.theme,
    fontFamily: fontFamily ?? this.fontFamily,
    scrolled: scrolled ?? this.scrolled,
  );

  factory ReaderSettings.fromJson(Map<String, dynamic> json) => ReaderSettings(
    fontSize: json['fontSize'] as int? ?? 18,
    lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
    theme: ReaderThemeMode.values.asNameMap()[json['theme']] ?? ReaderThemeMode.light,
    fontFamily: ReaderFontFamily.values.asNameMap()[json['fontFamily']] ?? ReaderFontFamily.publisher,
    scrolled: json['scrolled'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'theme': theme.name,
    'fontFamily': fontFamily.name,
    'scrolled': scrolled,
  };
}
