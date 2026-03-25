import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

/// Renders text using Flutter's TextPainter (full Unicode support).
/// Converts the result to an img.Image for compositing into the receipt.
class FlutterTextRenderer {
  FlutterTextRenderer._();

  /// Render a single line/paragraph of text to an img.Image.
  ///
  /// [text] The text to render (any Unicode script).
  /// [maxWidth] Maximum width in pixels for line wrapping.
  /// [fontSize] Font size in logical pixels.
  /// [bold] Whether to use bold weight.
  /// [align] Text alignment (left/center/right).
  ///
  /// Returns a record with the rendered image and its actual size.
  static Future<({img.Image image, int width, int height})> renderText(
    String text, {
    required int maxWidth,
    double fontSize = 22,
    bool bold = false,
    bool underline = false,
    bool italic = false,
    bool strikethrough = false,
    bool reverse = false,
    TextAlign align = TextAlign.left,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final fgColor = reverse ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final bgColor = reverse ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    final decoration = underline && strikethrough
        ? TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough])
        : underline
            ? TextDecoration.underline
            : strikethrough
                ? TextDecoration.lineThrough
                : TextDecoration.none;

    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: decoration,
      decorationColor: fgColor,
      color: fgColor,
      height: 1.2,
    );

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: textDirection,
      maxLines: null,
    );

    painter.layout(maxWidth: maxWidth.toDouble());

    final width = painter.width.ceil();
    final height = painter.height.ceil();

    if (width <= 0 || height <= 0) {
      return (
        image: img.Image(width: 1, height: 1),
        width: 0,
        height: 0,
      );
    }

    // Paint to a Flutter Canvas → ui.Image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Background (white normally, black for reverse mode)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = bgColor,
    );

    painter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(width, height);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    uiImage.dispose();

    if (byteData == null) {
      return (
        image: img.Image(width: 1, height: 1),
        width: 0,
        height: 0,
      );
    }

    // Convert RGBA bytes → img.Image
    final pixels = byteData.buffer.asUint8List();
    final result = img.Image(width: width, height: height, numChannels: 4);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        result.setPixelRgba(x, y, pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]);
      }
    }

    return (image: result, width: width, height: height);
  }

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
    // Check for RTL scripts: Arabic, Hebrew, Persian, Urdu
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
