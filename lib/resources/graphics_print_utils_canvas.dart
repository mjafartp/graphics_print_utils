import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

import 'flutter_text_renderer.dart';
import 'graphics_print_utils_manager.dart';

/// 1-bit monochrome image output for ESC/POS thermal printers.
///
/// Each byte packs 8 pixels, MSB first (standard ESC/POS raster format).
/// Width is padded to a multiple of 8.
class MonochromeImage {
  /// Packed 1-bit pixel data. Each byte = 8 pixels, MSB first.
  /// Black = 1, White = 0.
  final Uint8List bytes;

  /// Width in pixels (padded to multiple of 8).
  final int width;

  /// Height in pixels.
  final int height;

  /// Bytes per row (width ~/ 8).
  int get bytesPerRow => width ~/ 8;

  const MonochromeImage({
    required this.bytes,
    required this.width,
    required this.height,
  });
}

/// Flutter Canvas-based receipt renderer with monochrome 1-bit output.
///
/// Uses Flutter's TextPainter for text rendering — supports ALL Unicode scripts.
/// All operations are queued synchronously. [build] renders everything on a
/// single Canvas and outputs packed 1-bit monochrome bytes ready for ESC/POS
/// raster commands.
class GraphicsPrintUtils {
  final PrintMargin margin;
  final PrintPaperSize paperSize;
  final List<_PaintOp> _ops = [];

  /// Paper width padded to multiple of 8 for byte-aligned raster output.
  late final int _paddedWidth;

  GraphicsPrintUtils({
    this.paperSize = PrintPaperSize.mm80,
    this.margin = const PrintMargin(),
  }) {
    _paddedWidth = ((paperSize.width + 7) ~/ 8) * 8;
  }

  double _fontSize(PrintTextStyle style) =>
      FlutterTextRenderer.getFontSize(style.fontSize.name, paperSize == PrintPaperSize.mm58);

  TextAlign _mapAlign(PrintAlign align) => switch (align) {
    PrintAlign.left => TextAlign.left,
    PrintAlign.center => TextAlign.center,
    PrintAlign.right => TextAlign.right,
  };

  /// Queue text for rendering.
  void text(String text, {PrintTextStyle? style}) {
    if (text.isEmpty) return;
    _ops.add(_TextPaintOp(text, style ?? const PrintTextStyle()));
  }

  /// Queue row for rendering.
  void row({required List<PrintColumn> columns, int spacing = 10}) {
    if (columns.isEmpty) return;
    _ops.add(_RowPaintOp(columns, spacing));
  }

  /// Queue horizontal line.
  void line({int thickness = 1}) {
    _ops.add(_LinePaintOp(thickness));
  }

  /// Queue dotted horizontal line.
  void dottedLine({int thickness = 1, int dotWidth = 5, int spacing = 3}) {
    _ops.add(_DottedLinePaintOp(thickness, dotWidth, spacing));
  }

  /// Queue image for rendering from an [img.Image] instance.
  void image(img.Image subImage, {int? width, int? height, PrintAlign align = PrintAlign.left}) {
    _ops.add(_ImagePaintOp(subImage, width, height, align));
  }

  /// Queue image for rendering from raw bytes (PNG, JPEG, etc.).
  void imageBytes(Uint8List bytes, {int? width, int? height, PrintAlign align = PrintAlign.left}) {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      _ops.add(_ImagePaintOp(decoded, width, height, align));
    }
  }

  /// Queue QR code.
  void qr(String data, {int qrSize = 150, PrintAlign align = PrintAlign.center}) {
    _ops.add(_QrPaintOp(data, qrSize, align));
  }

  /// Queue barcode.
  void barcode(String data, {required Barcode barcode, int width = 300, int height = 120, PrintAlign align = PrintAlign.center}) {
    _ops.add(_BarcodePaintOp(data, barcode, width, height, align));
  }

  /// Queue blank lines.
  void feed({int lines = 1}) {
    _ops.add(_FeedPaintOp(lines));
  }

  /// Build the receipt as a 1-bit monochrome image.
  ///
  /// Renders all queued operations on a single Flutter Canvas, extracts RGBA
  /// pixels, and thresholds to 1-bit packed bytes (MSB first, black=1).
  Future<MonochromeImage> build() async {
    // Phase 1: Measure all ops to get total height
    final measurements = <_Measurement>[];
    int totalHeight = 0;
    final maxWidth = paperSize.width - margin.width;

    for (final op in _ops) {
      final m = _measure(op, maxWidth, totalHeight);
      measurements.add(m);
      totalHeight += m.height;
    }

    if (totalHeight <= 0) {
      return MonochromeImage(bytes: Uint8List(0), width: _paddedWidth, height: 0);
    }

    // Phase 2: Paint everything on ONE Canvas
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _paddedWidth.toDouble(), totalHeight.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // Paint all operations
    for (int i = 0; i < _ops.length; i++) {
      await _paintOp(canvas, _ops[i], measurements[i]);
    }

    final picture = recorder.endRecording();

    // Phase 3: Extract RGBA pixels
    ui.Image? uiImage;
    try {
      uiImage = picture.toImageSync(_paddedWidth, totalHeight);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData == null) {
        return MonochromeImage(bytes: Uint8List(0), width: _paddedWidth, height: 0);
      }

      // Phase 4: Threshold RGBA to 1-bit packed bytes
      final pixels = byteData.buffer.asUint8List();
      final monoBytes = _thresholdToMono(pixels, _paddedWidth, totalHeight);

      return MonochromeImage(bytes: monoBytes, width: _paddedWidth, height: totalHeight);
    } catch (_) {
      return MonochromeImage(bytes: Uint8List(0), width: _paddedWidth, height: 0);
    } finally {
      uiImage?.dispose();
      picture.dispose();
      _ops.clear();
    }
  }

  // ── Threshold ──

  /// Convert RGBA pixel data to 1-bit packed monochrome bytes.
  /// MSB first, black = 1, white = 0.
  Uint8List _thresholdToMono(Uint8List rgba, int width, int height) {
    final bytesPerRow = width ~/ 8;
    final monoBytes = Uint8List(bytesPerRow * height);

    for (int y = 0; y < height; y++) {
      final rowPixelOffset = y * width * 4;
      final rowByteOffset = y * bytesPerRow;

      for (int byteX = 0; byteX < bytesPerRow; byteX++) {
        int byte = 0;
        final baseX = byteX * 8;

        for (int bit = 0; bit < 8; bit++) {
          final i = rowPixelOffset + (baseX + bit) * 4;
          // Fast luminance: average of RGB channels
          final luminance = (rgba[i] + rgba[i + 1] + rgba[i + 2]) ~/ 3;
          if (luminance < 128) {
            byte |= (0x80 >> bit);
          }
        }

        monoBytes[rowByteOffset + byteX] = byte;
      }
    }

    return monoBytes;
  }

  // ── Measurement ──

  _Measurement _measure(_PaintOp op, int maxWidth, int currentY) {
    if (op is _TextPaintOp) {
      final s = op.style;
      final fs = _fontSize(s);
      final h = FlutterTextRenderer.measureHeight(op.text, maxWidth: maxWidth, fontSize: fs, bold: s.bold);
      return _Measurement(currentY, h.ceil() + 2);
    } else if (op is _RowPaintOp) {
      final totalWidth = paperSize.width - margin.width - (op.spacing * (op.columns.length - 1));
      final totalFlex = op.columns.fold(0, (sum, c) => sum + c.flex);
      int maxH = 0;
      for (final col in op.columns) {
        if (col.text.isEmpty) continue;
        final colWidth = (totalWidth * col.flex / totalFlex).round();
        final fs = _fontSize(col.style);
        final h = FlutterTextRenderer.measureHeight(col.text, maxWidth: colWidth, fontSize: fs, bold: col.style.bold);
        if (h.ceil() > maxH) maxH = h.ceil();
      }
      return _Measurement(currentY, maxH + 2);
    } else if (op is _LinePaintOp) {
      return _Measurement(currentY, op.thickness + 15);
    } else if (op is _DottedLinePaintOp) {
      return _Measurement(currentY, op.thickness + 15);
    } else if (op is _ImagePaintOp) {
      final h = op.targetHeight ?? op.subImage.height;
      return _Measurement(currentY, h + 5);
    } else if (op is _QrPaintOp) {
      return _Measurement(currentY, op.qrSize + 5);
    } else if (op is _BarcodePaintOp) {
      return _Measurement(currentY, op.height + 5);
    } else if (op is _FeedPaintOp) {
      final lineHeight = _fontSize(const PrintTextStyle()).round() + 10;
      return _Measurement(currentY, lineHeight * op.lines);
    }
    return _Measurement(currentY, 0);
  }

  // ── Paint operations ──

  Future<void> _paintOp(Canvas canvas, _PaintOp op, _Measurement m) async {
    if (op is _TextPaintOp) {
      _paintText(canvas, op, m);
    } else if (op is _RowPaintOp) {
      _paintRow(canvas, op, m);
    } else if (op is _LinePaintOp) {
      _paintLine(canvas, op, m);
    } else if (op is _DottedLinePaintOp) {
      _paintDottedLine(canvas, op, m);
    } else if (op is _ImagePaintOp) {
      await _paintImage(canvas, op, m);
    } else if (op is _QrPaintOp) {
      _paintQr(canvas, op, m);
    } else if (op is _BarcodePaintOp) {
      _paintBarcode(canvas, op, m);
    }
    // _FeedPaintOp = whitespace, nothing to paint
  }

  void _paintText(Canvas canvas, _TextPaintOp op, _Measurement m) {
    final s = op.style;
    final fs = _fontSize(s);
    final maxWidth = paperSize.width - margin.width;
    final direction = FlutterTextRenderer.detectDirection(op.text);

    final fgColor = s.reverse ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final decoration = s.underline && s.strikethrough
        ? TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough])
        : s.underline ? TextDecoration.underline
        : s.strikethrough ? TextDecoration.lineThrough
        : TextDecoration.none;

    final style = TextStyle(
      fontSize: fs,
      fontWeight: s.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
      decoration: decoration,
      decorationColor: fgColor,
      color: fgColor,
      height: 1.2,
    );

    final painter = TextPainter(
      text: TextSpan(text: op.text, style: style),
      textAlign: _mapAlign(s.align),
      textDirection: direction,
      maxLines: null,
    );
    painter.layout(maxWidth: maxWidth.toDouble());

    // Reverse background
    if (s.reverse) {
      canvas.drawRect(
        Rect.fromLTWH(margin.left.toDouble(), m.y.toDouble(), maxWidth.toDouble(), painter.height),
        Paint()..color = const Color(0xFF000000),
      );
    }

    double x = margin.left.toDouble();
    if (s.align == PrintAlign.center) {
      x = ((paperSize.width - painter.width) / 2).clamp(0, paperSize.width.toDouble());
    } else if (s.align == PrintAlign.right) {
      x = (paperSize.width - painter.width - margin.right).clamp(0, paperSize.width.toDouble());
    }

    painter.paint(canvas, Offset(x, m.y.toDouble()));
    painter.dispose();
  }

  void _paintRow(Canvas canvas, _RowPaintOp op, _Measurement m) {
    final totalWidth = paperSize.width - margin.width - (op.spacing * (op.columns.length - 1));
    final totalFlex = op.columns.fold(0, (sum, c) => sum + c.flex);

    double x = margin.left.toDouble();

    for (final col in op.columns) {
      final colWidth = (totalWidth * col.flex / totalFlex).round();
      if (col.text.isEmpty) {
        x += colWidth + op.spacing;
        continue;
      }

      final fs = _fontSize(col.style);
      final direction = FlutterTextRenderer.detectDirection(col.text);
      final fgColor = col.style.reverse ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

      final decoration = col.style.underline && col.style.strikethrough
          ? TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough])
          : col.style.underline ? TextDecoration.underline
          : col.style.strikethrough ? TextDecoration.lineThrough
          : TextDecoration.none;

      final style = TextStyle(
        fontSize: fs,
        fontWeight: col.style.bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: col.style.italic ? FontStyle.italic : FontStyle.normal,
        decoration: decoration,
        decorationColor: fgColor,
        color: fgColor,
        height: 1.2,
      );

      final painter = TextPainter(
        text: TextSpan(text: col.text, style: style),
        textAlign: _mapAlign(col.style.align),
        textDirection: direction,
        maxLines: null,
      );
      painter.layout(maxWidth: colWidth.toDouble());

      double colX = x;
      if (col.style.align == PrintAlign.center) {
        colX = x + ((colWidth - painter.width) / 2).clamp(0, colWidth.toDouble());
      } else if (col.style.align == PrintAlign.right) {
        colX = x + (colWidth - painter.width).clamp(0, colWidth.toDouble());
      }

      painter.paint(canvas, Offset(colX, m.y.toDouble()));
      painter.dispose();
      x += colWidth + op.spacing;
    }
  }

  void _paintLine(Canvas canvas, _LinePaintOp op, _Measurement m) {
    final y = m.y + 5;
    canvas.drawRect(
      Rect.fromLTWH(
        margin.left.toDouble(),
        y.toDouble(),
        (paperSize.width - margin.width).toDouble(),
        op.thickness.toDouble(),
      ),
      Paint()..color = const Color(0xFF000000),
    );
  }

  void _paintDottedLine(Canvas canvas, _DottedLinePaintOp op, _Measurement m) {
    final y = m.y + 5;
    final paint = Paint()..color = const Color(0xFF000000);
    int x = margin.left;
    while (x < paperSize.width - margin.right) {
      canvas.drawRect(
        Rect.fromLTWH(
          x.toDouble(),
          y.toDouble(),
          op.dotWidth.toDouble(),
          op.thickness.toDouble(),
        ),
        paint,
      );
      x += op.dotWidth + op.spacing;
    }
  }

  Future<void> _paintImage(Canvas canvas, _ImagePaintOp op, _Measurement m) async {
    final targetW = op.targetWidth ?? op.subImage.width;
    final targetH = op.targetHeight ?? op.subImage.height;

    // Resize if needed using image package
    final resized = (targetW != op.subImage.width || targetH != op.subImage.height)
        ? img.copyResize(op.subImage, width: targetW, height: targetH)
        : op.subImage;

    // Convert img.Image to ui.Image
    final uiImage = await _imgToUiImage(resized);

    try {
      int posX = margin.left;
      if (op.align == PrintAlign.center) {
        posX = ((paperSize.width - targetW) / 2).round();
      } else if (op.align == PrintAlign.right) {
        posX = paperSize.width - targetW - margin.right;
      }

      canvas.drawImage(uiImage, Offset(posX.toDouble(), m.y.toDouble()), Paint());
    } finally {
      uiImage.dispose();
    }
  }

  void _paintQr(Canvas canvas, _QrPaintOp op, _Measurement m) {
    final qrCode = QrCode.fromData(data: op.data, errorCorrectLevel: QrErrorCorrectLevel.M);
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    final pixelSize = (op.qrSize / moduleCount).floor();
    final paint = Paint()..color = const Color(0xFF000000);

    int posX = margin.left;
    if (op.align == PrintAlign.center) {
      posX = ((paperSize.width - op.qrSize) / 2).round();
    } else if (op.align == PrintAlign.right) {
      posX = paperSize.width - op.qrSize - margin.right;
    }

    // White background for QR
    canvas.drawRect(
      Rect.fromLTWH(posX.toDouble(), m.y.toDouble(), op.qrSize.toDouble(), op.qrSize.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    for (int row = 0; row < moduleCount; row++) {
      for (int col = 0; col < moduleCount; col++) {
        if (qrImage.isDark(col, row)) {
          canvas.drawRect(
            Rect.fromLTWH(
              (posX + col * pixelSize).toDouble(),
              (m.y + row * pixelSize).toDouble(),
              pixelSize.toDouble(),
              pixelSize.toDouble(),
            ),
            paint,
          );
        }
      }
    }
  }

  void _paintBarcode(Canvas canvas, _BarcodePaintOp op, _Measurement m) {
    final elements = op.barcode.make(op.data, width: op.width.toDouble(), height: op.height.toDouble());
    final paint = Paint()..color = const Color(0xFF000000);

    int posX = margin.left;
    if (op.align == PrintAlign.center) {
      posX = ((paperSize.width - op.width) / 2).round();
    } else if (op.align == PrintAlign.right) {
      posX = paperSize.width - op.width - margin.right;
    }

    // White background for barcode
    canvas.drawRect(
      Rect.fromLTWH(posX.toDouble(), m.y.toDouble(), op.width.toDouble(), op.height.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    for (final element in elements) {
      if (element is BarcodeBar && element.black) {
        canvas.drawRect(
          Rect.fromLTWH(
            posX + element.left,
            m.y + element.top,
            element.width,
            element.height,
          ),
          paint,
        );
      }
    }
  }

  // ── Helpers ──

  Future<ui.Image> _imgToUiImage(img.Image image) async {
    final pixels = image.getBytes(order: img.ChannelOrder.rgba);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      Uint8List.fromList(pixels),
      image.width,
      image.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

// ── Paint operation types ──

abstract class _PaintOp {}

class _TextPaintOp extends _PaintOp {
  final String text;
  final PrintTextStyle style;
  _TextPaintOp(this.text, this.style);
}

class _RowPaintOp extends _PaintOp {
  final List<PrintColumn> columns;
  final int spacing;
  _RowPaintOp(this.columns, this.spacing);
}

class _LinePaintOp extends _PaintOp {
  final int thickness;
  _LinePaintOp(this.thickness);
}

class _DottedLinePaintOp extends _PaintOp {
  final int thickness;
  final int dotWidth;
  final int spacing;
  _DottedLinePaintOp(this.thickness, this.dotWidth, this.spacing);
}

class _ImagePaintOp extends _PaintOp {
  final img.Image subImage;
  final int? targetWidth;
  final int? targetHeight;
  final PrintAlign align;
  _ImagePaintOp(this.subImage, this.targetWidth, this.targetHeight, this.align);
}

class _QrPaintOp extends _PaintOp {
  final String data;
  final int qrSize;
  final PrintAlign align;
  _QrPaintOp(this.data, this.qrSize, this.align);
}

class _BarcodePaintOp extends _PaintOp {
  final String data;
  final Barcode barcode;
  final int width;
  final int height;
  final PrintAlign align;
  _BarcodePaintOp(this.data, this.barcode, this.width, this.height, this.align);
}

class _FeedPaintOp extends _PaintOp {
  final int lines;
  _FeedPaintOp(this.lines);
}

class _Measurement {
  final int y;
  final int height;
  _Measurement(this.y, this.height);
}
