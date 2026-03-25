import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode_image/barcode_image.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

import 'flutter_text_renderer.dart';
import 'graphics_print_utils_manager.dart';

/// Flutter Canvas-based graphics print utility.
///
/// Uses Flutter's TextPainter for text rendering — supports ALL Unicode scripts
/// (Arabic, Hindi, Thai, Korean, Chinese, Japanese, Cyrillic, etc.) with
/// proper shaping, ligatures, and RTL layout.
///
/// Usage is identical to [GraphicsPrintUtils] but all methods are async:
/// ```dart
/// final g = GraphicsPrintUtilsCanvas(paperSize: PrintPaperSize.mm80);
/// await g.text('Hello مرحبا 你好 안녕');
/// await g.row(columns: [...]);
/// final png = g.build();
/// ```
class GraphicsPrintUtilsCanvas {
  late img.Image _image;
  int runningHeight = 0;
  final PrintMargin margin;
  final PrintPaperSize paperSize;

  static const int _initialHeight = 5000;
  static const double _growthFactor = 1.5;
  static const int _minGrowth = 200;

  GraphicsPrintUtilsCanvas({
    this.paperSize = PrintPaperSize.mm80,
    this.margin = const PrintMargin(),
    int? initialHeight,
  }) {
    final height = initialHeight ?? _initialHeight;
    _image = img.Image(width: paperSize.width, height: height, numChannels: 4);
    img.fillRect(_image,
        x1: 0, y1: 0, x2: paperSize.width, y2: height,
        color: img.ColorRgba8(255, 255, 255, 255));
  }

  void _ensureHeight(int required) {
    if (required <= _image.height) return;
    final current = _image.height;
    final growth = ((current * _growthFactor).round() - current).clamp(_minGrowth, current * 2);
    final newHeight = required > current + growth ? required + growth : (current * _growthFactor).round();

    final resized = img.Image(width: _image.width, height: newHeight, numChannels: 4);
    img.fillRect(resized, x1: 0, y1: 0, x2: _image.width, y2: newHeight,
        color: img.ColorRgba8(255, 255, 255, 255));
    img.compositeImage(resized, _image, blend: img.BlendMode.direct);
    _image = resized;
  }

  double _fontSize(PrintTextStyle style) =>
      FlutterTextRenderer.getFontSize(style.fontSize.name, paperSize == PrintPaperSize.mm58);

  TextAlign _mapAlign(PrintAlign align) => switch (align) {
    PrintAlign.left => TextAlign.left,
    PrintAlign.center => TextAlign.center,
    PrintAlign.right => TextAlign.right,
  };

  /// Draw text with full Unicode support.
  Future<void> text(String text, {PrintTextStyle? style}) async {
    if (text.isEmpty) return;
    final s = style ?? const PrintTextStyle();
    final fs = _fontSize(s);
    final maxWidth = paperSize.width - margin.width;
    final direction = FlutterTextRenderer.detectDirection(text);

    final result = await FlutterTextRenderer.renderText(
      text,
      maxWidth: maxWidth,
      fontSize: fs,
      bold: s.bold,
      align: _mapAlign(s.align),
      textDirection: direction,
    );

    if (result.height <= 0) return;

    // Calculate x position
    int x = margin.left;
    if (s.align == PrintAlign.center) {
      x = ((paperSize.width - result.width) / 2).round().clamp(0, paperSize.width);
    } else if (s.align == PrintAlign.right) {
      x = (paperSize.width - result.width - margin.right).clamp(0, paperSize.width);
    }

    _ensureHeight(runningHeight + result.height + 2);
    img.compositeImage(_image, result.image, dstX: x, dstY: runningHeight, blend: img.BlendMode.direct);
    runningHeight += result.height + 2;
  }

  /// Draw a row of columns with full Unicode support.
  Future<void> row({required List<PrintColumn> columns, int spacing = 10}) async {
    if (columns.isEmpty) return;

    final totalWidth = paperSize.width - margin.width - (spacing * (columns.length - 1));
    final totalFlex = columns.fold(0, (sum, c) => sum + c.flex);

    // Render each column and track max height
    final rendered = <({img.Image image, int width, int height, int colWidth})>[];
    int maxHeight = 0;

    for (final col in columns) {
      final colWidth = (totalWidth * col.flex / totalFlex).round();
      final fs = _fontSize(col.style);
      final direction = FlutterTextRenderer.detectDirection(col.text);

      if (col.text.isEmpty) {
        rendered.add((
          image: img.Image(width: 1, height: 1),
          width: 0,
          height: 0,
          colWidth: colWidth,
        ));
        continue;
      }

      final result = await FlutterTextRenderer.renderText(
        col.text,
        maxWidth: colWidth,
        fontSize: fs,
        bold: col.style.bold,
        align: _mapAlign(col.style.align),
        textDirection: direction,
      );

      rendered.add((
        image: result.image,
        width: result.width,
        height: result.height,
        colWidth: colWidth,
      ));
      if (result.height > maxHeight) maxHeight = result.height;
    }

    if (maxHeight <= 0) return;
    _ensureHeight(runningHeight + maxHeight + 2);

    // Composite each column at the right x position
    int x = margin.left;
    for (int i = 0; i < columns.length; i++) {
      final r = rendered[i];
      if (r.height > 0) {
        // Align within column
        int colX = x;
        if (columns[i].style.align == PrintAlign.center) {
          colX = x + ((r.colWidth - r.width) / 2).round().clamp(0, r.colWidth);
        } else if (columns[i].style.align == PrintAlign.right) {
          colX = x + (r.colWidth - r.width).clamp(0, r.colWidth);
        }

        img.compositeImage(_image, r.image, dstX: colX, dstY: runningHeight, blend: img.BlendMode.direct);
      }
      x += r.colWidth + spacing;
    }

    runningHeight += maxHeight + 2;
  }

  /// Draw horizontal line.
  void line({int thickness = 1}) {
    _ensureHeight(runningHeight + thickness + 15);
    runningHeight += 5;
    img.fillRect(_image,
        x1: margin.left, x2: paperSize.width - margin.right,
        y1: runningHeight, y2: runningHeight + thickness,
        color: img.ColorRgba8(0, 0, 0, 255));
    runningHeight += thickness + 10;
  }

  /// Draw dotted horizontal line.
  void dottedLine({int thickness = 1, int dotWidth = 5, int spacing = 3}) {
    _ensureHeight(runningHeight + thickness + 15);
    runningHeight += 5;
    int x = margin.left;
    while (x < paperSize.width - margin.right) {
      img.fillRect(_image,
          x1: x, x2: x + dotWidth,
          y1: runningHeight, y2: runningHeight + thickness,
          color: img.ColorRgba8(0, 0, 0, 255));
      x += dotWidth + spacing;
    }
    runningHeight += thickness + 10;
  }

  /// Draw image.
  void image(img.Image subImage, {int? width, int? height, PrintAlign align = PrintAlign.left}) {
    final resized = img.copyResize(subImage, width: width ?? subImage.width, height: height ?? subImage.height);
    _ensureHeight(runningHeight + resized.height + 5);

    int posX = margin.left;
    if (align == PrintAlign.center) {
      posX = ((paperSize.width - resized.width) / 2).round();
    } else if (align == PrintAlign.right) {
      posX = paperSize.width - resized.width - margin.right;
    }

    img.compositeImage(_image, resized, dstX: posX, dstY: runningHeight, blend: img.BlendMode.direct);
    runningHeight += resized.height + 5;
  }

  /// Draw QR code.
  void qr(String data, {int qrSize = 150, PrintAlign align = PrintAlign.center}) {
    final qrCode = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
    final qrImage = QrImage(qrCode);
    final drawQrImage = img.Image(width: qrSize, height: qrSize);
    img.fill(drawQrImage, color: img.ColorRgba8(255, 255, 255, 255));

    final moduleCount = qrImage.moduleCount;
    final pixelSize = (qrSize / moduleCount).floor();
    final black = img.ColorRgba8(0, 0, 0, 255);

    for (int y = 0; y < moduleCount; y++) {
      for (int x = 0; x < moduleCount; x++) {
        if (qrImage.isDark(x, y)) {
          img.fillRect(drawQrImage,
              x1: x * pixelSize, y1: y * pixelSize,
              x2: x * pixelSize + pixelSize, y2: y * pixelSize + pixelSize,
              color: black);
        }
      }
    }

    image(drawQrImage, align: align, width: qrSize, height: qrSize);
  }

  /// Draw barcode.
  void barcode(String data, {required Barcode barcode, int width = 300, int height = 120, PrintAlign align = PrintAlign.center}) {
    final bcImage = img.Image(width: width, height: height);
    img.fill(bcImage, color: img.ColorRgb8(255, 255, 255));
    drawBarcode(bcImage, barcode, data, width: width, height: height - 10);
    image(bcImage, align: align, width: width, height: height);
  }

  /// Feed lines.
  void feed({int lines = 1}) {
    final lineHeight = _fontSize(const PrintTextStyle()).round() + 8;
    _ensureHeight(runningHeight + lineHeight * lines);
    runningHeight += lineHeight * lines;
  }

  /// Build final PNG.
  Uint8List build() {
    final finalImage = img.copyCrop(_image, x: 0, y: 0, width: paperSize.width, height: runningHeight);
    return img.encodePng(finalImage);
  }
}
