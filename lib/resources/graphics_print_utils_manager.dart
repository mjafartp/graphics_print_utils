import 'dart:typed_data';

import 'package:barcode_image/barcode_image.dart';
import 'package:flutter/services.dart';
import 'package:graphics_print_utils/fonts/lithos_18.dart';
import 'package:graphics_print_utils/fonts/lithos_18_bold.dart';
import 'package:graphics_print_utils/fonts/lithos_22_bold.dart';
import 'package:graphics_print_utils/fonts/lithos_24.dart';
import 'package:graphics_print_utils/fonts/lithos_24_bold.dart';
import 'package:graphics_print_utils/fonts/lithos_26_bold.dart';
import 'package:graphics_print_utils/fonts/lithos_34_bold.dart';
import 'package:graphics_print_utils/fonts/lithos_40_bold.dart';
import 'package:graphics_print_utils/fonts/shape_arabic.dart';
import 'package:image/image.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

import '../fonts/lithos_22.dart';

class GraphicsPrintUtilsBitmap {
  late img.Image utilImage;
  int runningHeight = 0;
  PrintMargin margin = PrintMargin(left: 5, right: 5);
  final PrintPaperSize paperSize;
  BitmapFont font = lithos22;
  final textColor = ColorUint1.rgba(0, 0, 0, 255);

  // Dynamic height management constants
  static const int _initialHeight = 5000;
  static const double _growthFactor = 1.5;
  static const int _minGrowth = 200;

  // Optimized font lookup with map
  static final Map<String, BitmapFont Function()> _fontMap58 = {
    'small_false': () => lithos18,
    'small_true': () => lithos18Bold,
    'medium_false': () => lithos22,
    'medium_true': () => lithos22Bold,
    'large_false': () => lithos22Bold,
    'large_true': () => lithos26Bold,
  };

  static final Map<String, BitmapFont Function()> _fontMap80 = {
    'small_false': () => lithos22,
    'small_true': () => lithos22Bold,
    'medium_false': () => lithos24,
    'medium_true': () => lithos24Bold,
    'large_false': () => lithos34Bold,
    'large_true': () => lithos40Bold,
  };

  GraphicsPrintUtils({
    this.paperSize = PrintPaperSize.mm80,
    this.margin = const PrintMargin(),
    PrintTextStyle? style = const PrintTextStyle(),
    int? initialHeight,
  }) {
    final height = initialHeight ?? _initialHeight;

    utilImage = img.Image(
      width: paperSize.width,
      height: height,
      numChannels: 4,
    );

    img.fillRect(
      utilImage,
      x1: 0,
      y1: 0,
      x2: paperSize.width,
      y2: height,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    if (style != null) {
      font = _getFont(style, paperSize);
    }
  }

  BitmapFont _getFont(PrintTextStyle style, PrintPaperSize paperSize) {
    final map = paperSize == PrintPaperSize.mm58 ? _fontMap58 : _fontMap80;
    final key = '${style.fontSize.name}_${style.bold}';
    return map[key]?.call() ?? lithos22;
  }

  void _ensureHeight(int requiredHeight) {
    if (requiredHeight <= utilImage.height) {
      return;
    }

    final currentHeight = utilImage.height;
    // Fixed: use currentHeight instead of _initialHeight for exponential growth
    final growthAmount = (currentHeight * _growthFactor).round() - currentHeight;
    final actualGrowth = growthAmount > _minGrowth ? growthAmount : _minGrowth;

    final newHeight = (requiredHeight > currentHeight + actualGrowth)
        ? requiredHeight + actualGrowth
        : (currentHeight * _growthFactor).round();

    final resizedImage = img.Image(
      width: utilImage.width,
      height: newHeight,
      numChannels: 4,
    );

    // Optimized: only fill the NEW area, not the entire image
    img.fillRect(
      resizedImage,
      x1: 0,
      y1: 0,
      x2: utilImage.width,
      y2: newHeight,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    // Copy existing content to new image
    img.compositeImage(
      resizedImage,
      utilImage,
      blend: img.BlendMode.direct,
    );
    utilImage = resizedImage;
  }

  bool isArabic(String text) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');
    return arabicRegex.hasMatch(text);
  }

  /// Draw text - iterative multi-line rendering (no recursion)
  void text(String text, {PrintTextStyle? style}) {
    if (text.isEmpty) return;

    bool rtl = isArabic(text);
    img.BitmapFont textFont = font;
    PrintAlign align = PrintAlign.left;

    if (rtl) {
      textFont = lithos22;
      text = ShapeArabic.shape(text);
    }

    if (style != null) {
      textFont = _getFont(style, paperSize);
      align = style.align;
    }

    int maxWidth = paperSize.width - margin.width;

    // Split words once, reuse for all lines
    final words = text.split(' ');
    final nonEmptyWords = words.where((e) => e.isNotEmpty).toList(growable: false);
    if (nonEmptyWords.isEmpty) return;

    final lineHeight = textFont.lineHeight;
    final totalLineHeight = lineHeight + (lineHeight ~/ 12);

    // Iterative line processing - process all lines in a single pass
    int wordIndex = rtl ? nonEmptyWords.length - 1 : 0;

    while (rtl ? wordIndex >= 0 : wordIndex < nonEmptyWords.length) {
      final buffer = StringBuffer();
      int lastValidWidth = 0;
      int wordsInLine = 0;
      final int startIndex = wordIndex;

      // Build one line
      if (rtl) {
        for (int i = wordIndex; i >= 0; i--) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(nonEmptyWords[i]);

          final lineWidth = textFont.getMetrics(buffer.toString()).width;

          if (lineWidth <= maxWidth) {
            lastValidWidth = lineWidth;
            wordsInLine++;
            wordIndex = i - 1;
          } else {
            break;
          }
        }
      } else {
        for (int i = wordIndex; i < nonEmptyWords.length; i++) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(nonEmptyWords[i]);

          final lineWidth = textFont.getMetrics(buffer.toString()).width;

          if (lineWidth <= maxWidth) {
            lastValidWidth = lineWidth;
            wordsInLine++;
            wordIndex = i + 1;
          } else {
            break;
          }
        }
      }

      if (wordsInLine == 0) {
        // Word too long for line, force it
        wordsInLine = 1;
        final forcedWord = nonEmptyWords[rtl ? wordIndex + 1 : wordIndex];
        lastValidWidth = textFont.getMetrics(forcedWord).width;
        wordIndex = rtl ? wordIndex : wordIndex + 1;
      }

      // Build the line string
      final String currentLine;
      if (rtl) {
        final endIdx = startIndex;
        final startIdx = endIdx - wordsInLine + 1;
        currentLine = nonEmptyWords.sublist(startIdx, endIdx + 1).reversed.join(' ');
      } else {
        final startIdx = rtl ? startIndex : startIndex;
        currentLine = nonEmptyWords.sublist(startIdx, startIdx + wordsInLine).join(' ');
      }

      // Calculate x position
      int xPosition = margin.left;
      if (align == PrintAlign.center) {
        xPosition = ((paperSize.width - lastValidWidth) ~/ 2);
      } else if (align == PrintAlign.right) {
        final marginWidth = rtl ? margin.width : margin.left;
        xPosition = paperSize.width - lastValidWidth - marginWidth;
      }

      // Ensure height and draw
      _ensureHeight(runningHeight + totalLineHeight);

      drawString(
        utilImage,
        currentLine,
        font: textFont,
        x: xPosition,
        y: runningHeight,
        color: textColor,
      );

      runningHeight += totalLineHeight;
    }
  }

  /// Draw horizontal line
  void line({int thickness = 1}) {
    _ensureHeight(runningHeight + thickness + 15);
    runningHeight += 5;
    fillRect(
      utilImage,
      x1: margin.left,
      x2: paperSize.width - margin.right,
      y1: runningHeight,
      y2: runningHeight + thickness,
      color: textColor,
    );
    runningHeight += thickness + 10;
  }

  /// Draw dotted horizontal line
  void dottedLine({int thickness = 1, int dotWidth = 5, int spacing = 3}) {
    _ensureHeight(runningHeight + thickness + 15);
    runningHeight += 5;
    int x = margin.left;
    while (x < paperSize.width - margin.right) {
      fillRect(
        utilImage,
        x1: x,
        x2: x + dotWidth,
        y1: runningHeight,
        y2: runningHeight + thickness,
        color: textColor,
      );
      x += dotWidth + spacing;
    }
    runningHeight += thickness + 10;
  }

  /// Draw image (resized)
  void image(
    img.Image subImage, {
    int? width,
    int? height,
    PrintAlign align = PrintAlign.left,
  }) {
    final resized = copyResize(
      subImage,
      width: width ?? subImage.width,
      height: height ?? subImage.height,
    );

    _ensureHeight(runningHeight + resized.height + 5);

    int posX;
    final posY = runningHeight;

    if (align == PrintAlign.center) {
      posX = ((paperSize.width - resized.width) / 2).round();
    } else if (align == PrintAlign.right) {
      posX = paperSize.width - resized.width - margin.right;
    } else {
      posX = margin.left;
    }

    img.compositeImage(
      utilImage,
      resized,
      dstX: posX,
      dstY: posY,
      blend: img.BlendMode.direct,
    );
    runningHeight += (resized.height + 5);
  }

  /// Draw QR Code - uses fillRect for fast module rendering
  void qr(String data, {int qrSize = 150, PrintAlign align = PrintAlign.center}) {
    final qr = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qr);

    final drawQrImage = img.Image(width: qrSize, height: qrSize);
    fill(drawQrImage, color: ColorUint1.rgba(255, 255, 255, 255));

    final moduleCount = qrImage.moduleCount;
    final pixelSize = (qrSize / moduleCount).floor();
    final color = ColorUint1.rgba(0, 0, 0, 255);

    for (int y = 0; y < moduleCount; y++) {
      for (int x = 0; x < moduleCount; x++) {
        if (qrImage.isDark(x, y)) {
          final px = x * pixelSize;
          final py = y * pixelSize;
          fillRect(
            drawQrImage,
            x1: px,
            y1: py,
            x2: px + pixelSize,
            y2: py + pixelSize,
            color: color,
          );
        }
      }
    }

    image(drawQrImage, align: align, width: qrSize, height: qrSize);
  }

  void barcode(
    String data, {
    required Barcode barcode,
    int width = 300,
    int height = 120,
    PrintAlign align = PrintAlign.center,
  }) {
    final bcImage = img.Image(width: width, height: height);
    fill(bcImage, color: ColorRgb8(255, 255, 255));
    Barcode.code128();
    drawBarcode(
      bcImage,
      barcode,
      data,
      font: lithos22,
      width: width,
      height: height - 10,
    );
    image(
      bcImage,
      align: align,
      width: width,
      height: height,
    );
  }

  void row({required List<PrintColumn> columns, int spacing = 10}) {
    if (columns.isEmpty) return;

    int xPosition = margin.left;
    int totalWidth =
        paperSize.width - margin.width - (spacing * (columns.length - 1));
    int totalRatio = columns.fold(0, (sum, col) => sum + col.flex);

    int maxLines = 0;
    final List<List<String>> allColumnLines = [];

    // First pass: Calculate all lines for all columns
    for (PrintColumn column in columns) {
      if (column.text.isEmpty) {
        allColumnLines.add(['']);
        continue;
      }

      final columnFont = _getFont(column.style, paperSize);
      final columnWidth = (totalWidth * (column.flex / totalRatio)).round();

      final words = column.text.split(' ').where((w) => w.isNotEmpty).toList();
      if (words.isEmpty) {
        allColumnLines.add(['']);
        continue;
      }

      List<String> lines = [];
      String currentLine = '';

      for (int i = 0; i < words.length; i++) {
        final testLine = currentLine.isEmpty ? words[i] : '$currentLine ${words[i]}';
        final lineWidth = columnFont.getMetrics(testLine).width;

        if (lineWidth <= columnWidth) {
          currentLine = testLine;
        } else {
          if (currentLine.isNotEmpty) {
            lines.add(currentLine);
          }
          currentLine = words[i];
        }
      }
      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
      }

      if (lines.isEmpty) lines.add('');
      allColumnLines.add(lines);
      if (maxLines < lines.length) {
        maxLines = lines.length;
      }
    }

    // Second pass: Draw all columns
    final columnFont = _getFont(columns.first.style, paperSize);
    _ensureHeight(runningHeight + (maxLines * columnFont.lineHeight));
    final rowYPosition = runningHeight;

    for (int colIdx = 0; colIdx < columns.length; colIdx++) {
      final column = columns[colIdx];
      final lines = allColumnLines[colIdx];
      final columnFont = _getFont(column.style, paperSize);
      final columnWidth = (totalWidth * (column.flex / totalRatio)).round();
      final align = column.style.align;

      int tempRunningHeight = rowYPosition;

      for (String line in lines) {
        if (line.isEmpty) {
          tempRunningHeight += columnFont.lineHeight + (columnFont.lineHeight ~/ 12);
          continue;
        }

        final arabic = isArabic(line);
        final textFont = arabic ? lithos22 : columnFont;
        final shapedLine = arabic ? ShapeArabic.shape(line) : line;

        final lineWidth = textFont.getMetrics(shapedLine).width;
        int textXPosition = xPosition;

        if (align == PrintAlign.center) {
          textXPosition = xPosition + ((columnWidth - lineWidth) / 2).round();
        } else if (align == PrintAlign.right) {
          textXPosition = xPosition + (columnWidth - lineWidth).round();
        }

        drawString(
          utilImage,
          shapedLine,
          font: textFont,
          x: textXPosition,
          y: tempRunningHeight,
          color: textColor,
        );
        tempRunningHeight += columnFont.lineHeight + (columnFont.lineHeight ~/ 12);
      }

      xPosition += columnWidth + spacing;
    }

    runningHeight += (maxLines * columnFont.lineHeight) + (columnFont.lineHeight ~/ 12);
  }

  void feed({int lines = 1}) {
    _ensureHeight(runningHeight + font.lineHeight + 10);
    runningHeight += (font.lineHeight + 10) * lines;
  }

  /// Get final image as PNG using efficient copyCrop
  Uint8List build() {
    final finalImage = copyCrop(
      utilImage,
      x: 0,
      y: 0,
      width: paperSize.width,
      height: runningHeight,
    );
    return encodePng(finalImage);
  }
}

class PrintPaperSize {
  const PrintPaperSize._internal(this.width);
  final int width;
  static const mm58 = PrintPaperSize._internal(372);
  static const mm72 = PrintPaperSize._internal(503);
  static const mm80 = PrintPaperSize._internal(558);
  static const a4 = PrintPaperSize._internal(794);
  static const a3 = PrintPaperSize._internal(1123);

  /// Create a custom PaperSize with a specific width
  factory PrintPaperSize.custom(int width) {
    return PrintPaperSize._internal(width);
  }
}

class PrintTextStyle {
  final PrintFontSize fontSize;
  final PrintAlign align;
  final bool bold;
  final bool underline;
  final bool italic;
  final bool strikethrough;
  final bool reverse;

  const PrintTextStyle({
    this.fontSize = PrintFontSize.small,
    this.align = PrintAlign.left,
    this.bold = false,
    this.underline = false,
    this.italic = false,
    this.strikethrough = false,
    this.reverse = false,
  });

  PrintTextStyle copyWith({
    PrintFontSize? fontSize,
    PrintAlign? align,
    bool? bold,
    bool? underline,
    bool? italic,
    bool? strikethrough,
    bool? reverse,
  }) {
    return PrintTextStyle(
      fontSize: fontSize ?? this.fontSize,
      align: align ?? this.align,
      bold: bold ?? this.bold,
      underline: underline ?? this.underline,
      italic: italic ?? this.italic,
      strikethrough: strikethrough ?? this.strikethrough,
      reverse: reverse ?? this.reverse,
    );
  }
}

class PrintColumn {
  final String text;
  final int flex;
  final PrintTextStyle style;

  PrintColumn(this.text, {this.flex = 1, this.style = const PrintTextStyle()});
}

enum PrintAlign { left, center, right }

enum PrintFontSize { small, medium, large }

class PrintMargin {
  final int left;
  final int right;

  const PrintMargin({this.left = 2, this.right = 2});
  int get width => left + right;
}
