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
/// Uses Flutter's TextPainter for text rendering — supports ALL Unicode scripts.
/// All text/row operations are queued and painted in a single batch at build() time
/// for maximum performance.
class GraphicsPrintUtils {
  final PrintMargin margin;
  final PrintPaperSize paperSize;
  final List<_PaintOp> _ops = [];

  // Track running height for non-text ops (lines, images, qr, barcode, feed)
  int _estimatedHeight = 0;

  GraphicsPrintUtils({
    this.paperSize = PrintPaperSize.mm80,
    this.margin = const PrintMargin(),
    PrintTextStyle? style,
    int? initialHeight,
  });

  double _fontSize(PrintTextStyle style) =>
      FlutterTextRenderer.getFontSize(style.fontSize.name, paperSize == PrintPaperSize.mm58);

  TextAlign _mapAlign(PrintAlign align) => switch (align) {
    PrintAlign.left => TextAlign.left,
    PrintAlign.center => TextAlign.center,
    PrintAlign.right => TextAlign.right,
  };

  /// Queue text for rendering. Actual painting happens at build().
  Future<void> text(String text, {PrintTextStyle? style}) async {
    if (text.isEmpty) return;
    final s = style ?? const PrintTextStyle();
    _ops.add(_TextPaintOp(text, s));
  }

  /// Queue row for rendering. Actual painting happens at build().
  Future<void> row({required List<PrintColumn> columns, int spacing = 10}) async {
    if (columns.isEmpty) return;
    _ops.add(_RowPaintOp(columns, spacing));
  }

  /// Draw horizontal line (immediate — no text involved).
  void line({int thickness = 1}) {
    _ops.add(_LinePaintOp(thickness));
  }

  /// Draw dotted horizontal line.
  void dottedLine({int thickness = 1, int dotWidth = 5, int spacing = 3}) {
    _ops.add(_DottedLinePaintOp(thickness, dotWidth, spacing));
  }

  /// Draw image.
  void image(img.Image subImage, {int? width, int? height, PrintAlign align = PrintAlign.left}) {
    _ops.add(_ImagePaintOp(subImage, width, height, align));
  }

  /// Draw QR code.
  void qr(String data, {int qrSize = 150, PrintAlign align = PrintAlign.center}) {
    _ops.add(_QrPaintOp(data, qrSize, align));
  }

  /// Draw barcode.
  void barcode(String data, {required Barcode barcode, int width = 300, int height = 120, PrintAlign align = PrintAlign.center}) {
    _ops.add(_BarcodePaintOp(data, barcode, width, height, align));
  }

  /// Feed lines.
  void feed({int lines = 1}) {
    _ops.add(_FeedPaintOp(lines));
  }

  /// Build final PNG. This is where ALL rendering happens in one batch.
  ///
  /// 1. Measure all text/row heights using TextPainter.layout() (no toImage)
  /// 2. Create one big Canvas for the full receipt
  /// 3. Paint all text/rows onto it in one pass
  /// 4. Call toImage() ONCE
  /// 5. Composite non-text elements (lines, images, QR, barcode) onto img.Image
  /// 6. Encode as PNG
  Uint8List build() {
    // Phase 1: Measure all ops to get total height
    final measurements = <_Measurement>[];
    int totalHeight = 0;
    final maxWidth = paperSize.width - margin.width;

    for (final op in _ops) {
      final m = _measure(op, maxWidth, totalHeight);
      measurements.add(m);
      totalHeight += m.height;
    }

    if (totalHeight <= 0) totalHeight = 1;

    // Phase 2: Create the full receipt image with white background
    final fullImage = img.Image(width: paperSize.width, height: totalHeight, numChannels: 4);
    img.fillRect(fullImage, x1: 0, y1: 0, x2: paperSize.width, y2: totalHeight,
        color: img.ColorRgba8(255, 255, 255, 255));

    // Phase 3: Paint non-text ops directly onto img.Image
    // Collect text ops for batch Canvas rendering
    final textPaints = <_TextPaint>[];

    for (int i = 0; i < _ops.length; i++) {
      final op = _ops[i];
      final m = measurements[i];

      if (op is _LinePaintOp) {
        final y = m.y + 5;
        img.fillRect(fullImage,
            x1: margin.left, x2: paperSize.width - margin.right,
            y1: y, y2: y + op.thickness,
            color: img.ColorRgba8(0, 0, 0, 255));
      } else if (op is _DottedLinePaintOp) {
        final y = m.y + 5;
        int x = margin.left;
        while (x < paperSize.width - margin.right) {
          img.fillRect(fullImage,
              x1: x, x2: x + op.dotWidth,
              y1: y, y2: y + op.thickness,
              color: img.ColorRgba8(0, 0, 0, 255));
          x += op.dotWidth + op.spacing;
        }
      } else if (op is _ImagePaintOp) {
        final resized = img.copyResize(op.subImage,
            width: op.targetWidth ?? op.subImage.width,
            height: op.targetHeight ?? op.subImage.height);
        int posX = margin.left;
        if (op.align == PrintAlign.center) {
          posX = ((paperSize.width - resized.width) / 2).round();
        } else if (op.align == PrintAlign.right) {
          posX = paperSize.width - resized.width - margin.right;
        }
        img.compositeImage(fullImage, resized, dstX: posX, dstY: m.y, blend: img.BlendMode.direct);
      } else if (op is _QrPaintOp) {
        final qrCode = QrCode.fromData(data: op.data, errorCorrectLevel: QrErrorCorrectLevel.M);
        final qrImage = QrImage(qrCode);
        final drawQr = img.Image(width: op.qrSize, height: op.qrSize);
        img.fill(drawQr, color: img.ColorRgba8(255, 255, 255, 255));
        final moduleCount = qrImage.moduleCount;
        final pixelSize = (op.qrSize / moduleCount).floor();
        final black = img.ColorRgba8(0, 0, 0, 255);
        for (int y = 0; y < moduleCount; y++) {
          for (int x = 0; x < moduleCount; x++) {
            if (qrImage.isDark(x, y)) {
              img.fillRect(drawQr, x1: x * pixelSize, y1: y * pixelSize,
                  x2: x * pixelSize + pixelSize, y2: y * pixelSize + pixelSize, color: black);
            }
          }
        }
        int posX = margin.left;
        if (op.align == PrintAlign.center) posX = ((paperSize.width - op.qrSize) / 2).round();
        else if (op.align == PrintAlign.right) posX = paperSize.width - op.qrSize - margin.right;
        img.compositeImage(fullImage, drawQr, dstX: posX, dstY: m.y, blend: img.BlendMode.direct);
      } else if (op is _BarcodePaintOp) {
        final bcImage = img.Image(width: op.width, height: op.height);
        img.fill(bcImage, color: img.ColorRgb8(255, 255, 255));
        drawBarcode(bcImage, op.barcode, op.data, width: op.width, height: op.height - 10);
        int posX = margin.left;
        if (op.align == PrintAlign.center) posX = ((paperSize.width - op.width) / 2).round();
        else if (op.align == PrintAlign.right) posX = paperSize.width - op.width - margin.right;
        img.compositeImage(fullImage, bcImage, dstX: posX, dstY: m.y, blend: img.BlendMode.direct);
      } else if (op is _TextPaintOp) {
        textPaints.add(_TextPaint(op, m));
      } else if (op is _RowPaintOp) {
        textPaints.add(_TextPaint(op, m));
      }
      // _FeedPaintOp = just whitespace, nothing to paint
    }

    // Phase 4: Batch-render ALL text onto one Canvas → one toImage()
    if (textPaints.isNotEmpty) {
      final textImage = _batchRenderText(textPaints, paperSize.width, totalHeight);
      if (textImage != null) {
        img.compositeImage(fullImage, textImage, blend: img.BlendMode.direct);
      }
    }

    return img.encodePng(fullImage);
  }

  // ── Measurement ──

  _Measurement _measure(_PaintOp op, int maxWidth, int currentY) {
    if (op is _TextPaintOp) {
      final s = op.style;
      final fs = _fontSize(s);
      final h = FlutterTextRenderer.measureHeight(op.text, maxWidth: maxWidth, fontSize: fs, bold: s.bold);
      final height = h.ceil() + 2;
      return _Measurement(currentY, height);
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

  // ── Batch text rendering (ONE Canvas, ONE toImage) ──

  img.Image? _batchRenderText(List<_TextPaint> paints, int width, int height) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    for (final tp in paints) {
      if (tp.op is _TextPaintOp) {
        _paintText(canvas, tp.op as _TextPaintOp, tp.measurement, width);
      } else if (tp.op is _RowPaintOp) {
        _paintRow(canvas, tp.op as _RowPaintOp, tp.measurement, width);
      }
    }

    final picture = recorder.endRecording();

    // ONE toImage call for ALL text
    final ui.Image uiImage;
    try {
      uiImage = picture.toImageSync(width, height);
    } catch (_) {
      picture.dispose();
      return null;
    }

    final byteData = uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();

    if (byteData == null) {
      uiImage.dispose();
      return null;
    }

    final pixels = byteData.buffer.asUint8List();
    final result = img.Image(width: width, height: height, numChannels: 4);

    // Fast pixel copy — only copy non-white pixels (text is black on transparent)
    for (int y = 0; y < height; y++) {
      final rowOffset = y * width * 4;
      for (int x = 0; x < width; x++) {
        final i = rowOffset + x * 4;
        final a = pixels[i + 3];
        if (a > 0) {
          result.setPixelRgba(x, y, pixels[i], pixels[i + 1], pixels[i + 2], a);
        }
      }
    }

    uiImage.dispose();
    return result;
  }

  void _paintText(Canvas canvas, _TextPaintOp op, _Measurement m, int canvasWidth) {
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

    // Position
    double x = margin.left.toDouble();
    if (s.align == PrintAlign.center) {
      x = ((paperSize.width - painter.width) / 2).clamp(0, paperSize.width.toDouble());
    } else if (s.align == PrintAlign.right) {
      x = (paperSize.width - painter.width - margin.right).clamp(0, paperSize.width.toDouble());
    }

    painter.paint(canvas, Offset(x, m.y.toDouble()));
  }

  void _paintRow(Canvas canvas, _RowPaintOp op, _Measurement m, int canvasWidth) {
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

      // Column alignment
      double colX = x;
      if (col.style.align == PrintAlign.center) {
        colX = x + ((colWidth - painter.width) / 2).clamp(0, colWidth.toDouble());
      } else if (col.style.align == PrintAlign.right) {
        colX = x + (colWidth - painter.width).clamp(0, colWidth.toDouble());
      }

      painter.paint(canvas, Offset(colX, m.y.toDouble()));
      x += colWidth + op.spacing;
    }
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

class _TextPaint {
  final _PaintOp op;
  final _Measurement measurement;
  _TextPaint(this.op, this.measurement);
}
