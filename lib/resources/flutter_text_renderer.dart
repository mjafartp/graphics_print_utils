import 'package:flutter/painting.dart';

/// Measurement and text utility for Flutter TextPainter.
class FlutterTextRenderer {
  FlutterTextRenderer._();

  /// Get the font size in pixels for a given PrintFontSize-like enum.
  static double getFontSize(String size, bool is58mm) {
    if (is58mm) {
      return switch (size) {
        'small' => 16,
        'medium' => 20,
        'large' => 26,
        _ => 20,
      };
    }
    return switch (size) {
      'small' => 20,
      'medium' => 24,
      'large' => 34,
      _ => 24,
    };
  }

  /// Detect text direction based on content.
  static TextDirection detectDirection(String text) {
    final rtlRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\u0590-\u05FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    if (rtlRegex.hasMatch(text)) return TextDirection.rtl;
    return TextDirection.ltr;
  }

  /// Measure text width without rendering.
  static double measureWidth(
    String text, {
    required int maxWidth,
    double fontSize = 22,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: detectDirection(text),
      maxLines: 1,
    );
    painter.layout(maxWidth: maxWidth.toDouble());
    return painter.width;
  }

  /// Measure text height with wrapping.
  static double measureHeight(
    String text, {
    required int maxWidth,
    double fontSize = 22,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          height: 1.2,
        ),
      ),
      textDirection: detectDirection(text),
      maxLines: null,
    );
    painter.layout(maxWidth: maxWidth.toDouble());
    return painter.height;
  }
}
