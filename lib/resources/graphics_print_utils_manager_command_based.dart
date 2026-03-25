import 'dart:isolate';
import 'dart:typed_data';

import 'package:barcode_image/barcode_image.dart';
import 'package:graphics_print_utils/fonts/lithos_18.dart';
import 'package:graphics_print_utils/fonts/lithos_18_bold.dart';
import 'package:graphics_print_utils/fonts/lithos_22.dart';
import 'package:graphics_print_utils/fonts/lithos_22_bold.dart';
import 'package:graphics_print_utils/fonts/lithos_24.dart';
import 'package:graphics_print_utils/fonts/lithos_24_bold.dart';
import 'package:graphics_print_utils/fonts/lithos_26_bold.dart';
import 'package:graphics_print_utils/fonts/lithos_34_bold.dart';
import 'package:graphics_print_utils/fonts/lithos_40_bold.dart';
import 'package:graphics_print_utils/resources/graphics_print_utils_manager.dart';
import 'package:graphics_print_utils/resources/graphics_print_utils_canvas.dart';
import 'package:image/image.dart' as img;
import 'package:image/image.dart' show BitmapFont;

// Command types for queuing operations
abstract class _DrawCommand {
  void execute(GraphicsPrintUtilsBitmap util);
}

class _TextCommand extends _DrawCommand {
  final String text;
  final PrintTextStyle? style;
  _TextCommand(this.text, this.style);
  @override
  void execute(GraphicsPrintUtilsBitmap util) => util.text(text, style: style);
}

class _LineCommand extends _DrawCommand {
  final int thickness;
  _LineCommand(this.thickness);
  @override
  void execute(GraphicsPrintUtilsBitmap util) => util.line(thickness: thickness);
}

class _DottedLineCommand extends _DrawCommand {
  final int thickness;
  final int dotWidth;
  final int spacing;
  _DottedLineCommand(this.thickness, this.dotWidth, this.spacing);
  @override
  void execute(GraphicsPrintUtilsBitmap util) => util.dottedLine(
        thickness: thickness,
        dotWidth: dotWidth,
        spacing: spacing,
      );
}

class _ImageCommand extends _DrawCommand {
  final Uint8List rawPixelBytes;
  final int imageWidth;
  final int imageHeight;
  final int? targetWidth;
  final int? targetHeight;
  final PrintAlign align;
  _ImageCommand(
    this.rawPixelBytes,
    this.imageWidth,
    this.imageHeight,
    this.targetWidth,
    this.targetHeight,
    this.align,
  );
  @override
  void execute(GraphicsPrintUtilsBitmap util) {
    // Reconstruct image from raw pixel bytes (no PNG decode needed)
    final decodedImage = img.Image.fromBytes(
      width: imageWidth,
      height: imageHeight,
      bytes: rawPixelBytes.buffer,
      numChannels: 4,
    );
    util.image(
      decodedImage,
      width: targetWidth,
      height: targetHeight,
      align: align,
    );
  }
}

class _QrCommand extends _DrawCommand {
  final String data;
  final int qrSize;
  final PrintAlign align;
  _QrCommand(this.data, this.qrSize, this.align);
  @override
  void execute(GraphicsPrintUtilsBitmap util) => util.qr(
        data,
        qrSize: qrSize,
        align: align,
      );
}

class _BarcodeCommand extends _DrawCommand {
  final String data;
  final String barcodeType;
  final int width;
  final int height;
  final PrintAlign align;
  _BarcodeCommand(this.data, this.barcodeType, this.width, this.height, this.align);
  @override
  void execute(GraphicsPrintUtilsBitmap util) {
    Barcode barcode;
    switch (barcodeType) {
      case 'code128':
        barcode = Barcode.code128();
        break;
      case 'code39':
        barcode = Barcode.code39();
        break;
      case 'ean13':
        barcode = Barcode.ean13();
        break;
      case 'ean8':
        barcode = Barcode.ean8();
        break;
      case 'itf':
        barcode = Barcode.itf();
        break;
      case 'upcA':
        barcode = Barcode.upcA();
        break;
      case 'upcE':
        barcode = Barcode.upcE();
        break;
      default:
        barcode = Barcode.code128();
    }
    util.barcode(
      data,
      barcode: barcode,
      width: width,
      height: height,
      align: align,
    );
  }
}

class _RowCommand extends _DrawCommand {
  final List<PrintColumn> columns;
  final int spacing;
  _RowCommand(this.columns, this.spacing);
  @override
  void execute(GraphicsPrintUtilsBitmap util) => util.row(
        columns: columns,
        spacing: spacing,
      );
}

class _FeedCommand extends _DrawCommand {
  final int lines;
  _FeedCommand(this.lines);
  @override
  void execute(GraphicsPrintUtilsBitmap util) => util.feed(lines: lines);
}

/// Command-based version of GraphicsPrintUtilsBitmap that queues operations
/// and executes them in an isolate when build() is called.
///
/// This allows you to prepare all drawing operations synchronously,
/// then execute them in a background isolate to keep the UI responsive.
/// Canvas-based command queue. Queues operations synchronously,
/// executes with Flutter Canvas renderer on build().
/// Full Unicode support for all languages.
class GraphicsPrintUtilsCommandBased {
  final PrintPaperSize paperSize;
  final PrintMargin margin;
  final PrintTextStyle? style;
  final List<_DrawCommand> _commandQueue = [];

  GraphicsPrintUtilsCommandBased({
    this.paperSize = PrintPaperSize.mm80,
    this.margin = const PrintMargin(),
    this.style,
  });

  void text(String text, {PrintTextStyle? style}) =>
      _commandQueue.add(_TextCommand(text, style));

  void line({int thickness = 1}) =>
      _commandQueue.add(_LineCommand(thickness));

  void dottedLine({int thickness = 1, int dotWidth = 5, int spacing = 3}) =>
      _commandQueue.add(_DottedLineCommand(thickness, dotWidth, spacing));

  void image(img.Image subImage, {int? width, int? height, PrintAlign align = PrintAlign.left}) {
    final rawBytes = subImage.toUint8List();
    _commandQueue.add(_ImageCommand(rawBytes, subImage.width, subImage.height, width, height, align));
  }

  void qr(String data, {int qrSize = 150, PrintAlign align = PrintAlign.center}) =>
      _commandQueue.add(_QrCommand(data, qrSize, align));

  void barcode(String data, {required Barcode barcode, int width = 300, int height = 120, PrintAlign align = PrintAlign.center}) {
    final typeName = barcode.runtimeType.toString().toLowerCase();
    String barcodeType = 'code128';
    if (typeName.contains('code39')) barcodeType = 'code39';
    else if (typeName.contains('ean13')) barcodeType = 'ean13';
    else if (typeName.contains('ean8')) barcodeType = 'ean8';
    else if (typeName.contains('itf')) barcodeType = 'itf';
    else if (typeName.contains('upca')) barcodeType = 'upcA';
    else if (typeName.contains('upce')) barcodeType = 'upcE';
    _commandQueue.add(_BarcodeCommand(data, barcodeType, width, height, align));
  }

  void row({required List<PrintColumn> columns, int spacing = 10}) =>
      _commandQueue.add(_RowCommand(columns, spacing));

  void feed({int lines = 1}) =>
      _commandQueue.add(_FeedCommand(lines));

  /// Execute all queued operations using Flutter Canvas renderer.
  /// Returns PNG bytes. Must be called on the main isolate (Flutter binding required).
  Future<Uint8List> build() async {
    final g = GraphicsPrintUtils(paperSize: paperSize, margin: margin);

    for (final command in _commandQueue) {
      await _executeCanvas(g, command);
    }

    return g.build();
  }

  Future<void> _executeCanvas(GraphicsPrintUtils g, _DrawCommand command) async {
    if (command is _TextCommand) {
      await g.text(command.text, style: command.style);
    } else if (command is _LineCommand) {
      g.line(thickness: command.thickness);
    } else if (command is _DottedLineCommand) {
      g.dottedLine(thickness: command.thickness, dotWidth: command.dotWidth, spacing: command.spacing);
    } else if (command is _ImageCommand) {
      final subImage = img.Image.fromBytes(
        width: command.imageWidth,
        height: command.imageHeight,
        bytes: command.imageData.buffer,
        numChannels: 4,
      );
      g.image(subImage, width: command.targetWidth, height: command.targetHeight, align: command.align);
    } else if (command is _QrCommand) {
      g.qr(command.data, qrSize: command.qrSize, align: command.align);
    } else if (command is _BarcodeCommand) {
      final bc = _resolveBarcodeType(command.barcodeType);
      g.barcode(command.data, barcode: bc, width: command.width, height: command.height, align: command.align);
    } else if (command is _RowCommand) {
      await g.row(columns: command.columns, spacing: command.spacing);
    } else if (command is _FeedCommand) {
      g.feed(lines: command.lines);
    }
  }

  Barcode _resolveBarcodeType(String type) => switch (type) {
    'code128' => Barcode.code128(),
    'code39' => Barcode.code39(),
    'ean13' => Barcode.ean13(),
    'ean8' => Barcode.ean8(),
    'itf' => Barcode.itf(),
    'upcA' => Barcode.upcA(),
    'upcE' => Barcode.upcE(),
    _ => Barcode.code128(),
  };

  void clear() {
    _commandQueue.clear();
  }

  int get commandCount => _commandQueue.length;
}

/// Bitmap-based command queue (old method, works in isolate).
class GraphicsPrintUtilsBitmapCommandBased {
  final PrintPaperSize paperSize;
  final PrintMargin margin;
  final PrintTextStyle? style;
  final List<_DrawCommand> _commandQueue = [];
  int _estimatedHeight = 0;

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

  GraphicsPrintUtilsBitmapCommandBased({
    this.paperSize = PrintPaperSize.mm80,
    this.margin = const PrintMargin(),
    this.style,
  });

  /// Add text to the drawing queue
  void text(String text, {PrintTextStyle? style}) {
    final command = _TextCommand(text, style);
    _commandQueue.add(command);
    _addEstimatedHeight(command);
  }

  /// Add a horizontal line to the drawing queue
  void line({int thickness = 1}) {
    final command = _LineCommand(thickness);
    _commandQueue.add(command);
    _addEstimatedHeight(command);
  }

  /// Add a dotted horizontal line to the drawing queue
  void dottedLine({
    int thickness = 1,
    int dotWidth = 5,
    int spacing = 3,
  }) {
    final command = _DottedLineCommand(thickness, dotWidth, spacing);
    _commandQueue.add(command);
    _addEstimatedHeight(command);
  }

  /// Add an image to the drawing queue.
  /// Uses raw pixel bytes for efficient isolate transfer (no PNG encode/decode).
  void image(
    img.Image subImage, {
    int? width,
    int? height,
    PrintAlign align = PrintAlign.left,
  }) {
    // Use raw pixel bytes instead of PNG encoding for faster isolate transfer
    final rawBytes = subImage.toUint8List();
    final command = _ImageCommand(
      rawBytes,
      subImage.width,
      subImage.height,
      width,
      height,
      align,
    );
    _commandQueue.add(command);
    _addEstimatedHeight(command);
  }

  /// Add a QR code to the drawing queue
  void qr(
    String data, {
    int qrSize = 150,
    PrintAlign align = PrintAlign.center,
  }) {
    final command = _QrCommand(data, qrSize, align);
    _commandQueue.add(command);
    _addEstimatedHeight(command);
  }

  /// Add a barcode to the drawing queue
  void barcode(
    String data, {
    required Barcode barcode,
    int width = 300,
    int height = 120,
    PrintAlign align = PrintAlign.center,
  }) {
    String barcodeType;
    final typeName = barcode.runtimeType.toString().toLowerCase();
    if (typeName.contains('code128')) {
      barcodeType = 'code128';
    } else if (typeName.contains('code39')) {
      barcodeType = 'code39';
    } else if (typeName.contains('ean13')) {
      barcodeType = 'ean13';
    } else if (typeName.contains('ean8')) {
      barcodeType = 'ean8';
    } else if (typeName.contains('itf')) {
      barcodeType = 'itf';
    } else if (typeName.contains('upca')) {
      barcodeType = 'upcA';
    } else if (typeName.contains('upce')) {
      barcodeType = 'upcE';
    } else {
      barcodeType = 'code128';
    }
    final command = _BarcodeCommand(data, barcodeType, width, height, align);
    _commandQueue.add(command);
    _addEstimatedHeight(command);
  }

  /// Add a row to the drawing queue
  void row({
    required List<PrintColumn> columns,
    int spacing = 10,
  }) {
    final command = _RowCommand(columns, spacing);
    _commandQueue.add(command);
    _addEstimatedHeight(command);
  }

  /// Add feed (blank lines) to the drawing queue
  void feed({int lines = 1}) {
    final command = _FeedCommand(lines);
    _commandQueue.add(command);
    _addEstimatedHeight(command);
  }

  void _addEstimatedHeight(_DrawCommand command) {
    _estimatedHeight += _calculateCommandHeight(command);
  }

  int _calculateCommandHeight(_DrawCommand command) {
    if (command is _TextCommand) {
      return _estimateTextHeight(command.text, command.style);
    } else if (command is _LineCommand || command is _DottedLineCommand) {
      final thickness = command is _LineCommand
          ? command.thickness
          : (command as _DottedLineCommand).thickness;
      return _estimateLineHeight(thickness);
    } else if (command is _ImageCommand) {
      final resolvedHeight = command.targetHeight ?? command.imageHeight;
      return resolvedHeight + 5;
    } else if (command is _QrCommand) {
      return command.qrSize + 5;
    } else if (command is _BarcodeCommand) {
      return command.height + 5;
    } else if (command is _RowCommand) {
      return _estimateRowHeight(command);
    } else if (command is _FeedCommand) {
      return _estimateFeedHeight(command.lines);
    }
    return 0;
  }

  BitmapFont _resolveFont(PrintTextStyle? overrideStyle) {
    final effectiveStyle = overrideStyle ?? style ?? const PrintTextStyle();
    final map = paperSize == PrintPaperSize.mm58 ? _fontMap58 : _fontMap80;
    final key = '${effectiveStyle.fontSize.name}_${effectiveStyle.bold}';
    return map[key]?.call() ?? lithos22;
  }

  int _estimateTextHeight(String text, PrintTextStyle? textStyle) {
    if (text.isEmpty) return 0;

    final font = _resolveFont(textStyle);
    final maxWidth = paperSize.width - margin.width;
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 0;

    int lineCount = 0;
    int wordIndex = 0;

    while (wordIndex < words.length) {
      final buffer = StringBuffer();
      int wordsInLine = 0;

      while (wordIndex < words.length) {
        final word = words[wordIndex];
        final testLine = buffer.isEmpty ? word : '${buffer.toString()} $word';
        final lineWidth = font.getMetrics(testLine).width;
        if (lineWidth <= maxWidth) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(word);
          wordsInLine++;
          wordIndex++;
        } else {
          break;
        }
      }

      if (wordsInLine == 0) {
        wordsInLine = 1;
        wordIndex++;
      }

      lineCount++;
    }

    final lineHeight = font.lineHeight.toInt();
    final totalHeight = lineHeight + (lineHeight ~/ 12);
    return totalHeight * lineCount;
  }

  int _estimateRowHeight(_RowCommand command) {
    if (command.columns.isEmpty) {
      return 0;
    }
    final totalWidth =
        paperSize.width - margin.width - (command.spacing * (command.columns.length - 1));
    final totalRatio = command.columns.fold(0, (sum, col) => sum + col.flex);

    int maxLines = 0;
    for (final column in command.columns) {
      final columnFont = _resolveFont(column.style);
      final columnWidth = (totalWidth * (column.flex / totalRatio)).round();
      final words = column.text.split(' ').where((w) => w.isNotEmpty).toList();

      if (words.isEmpty) {
        maxLines = maxLines > 0 ? maxLines : 1;
        continue;
      }

      int lineCount = 0;
      String currentLine = '';
      for (final word in words) {
        final testLine = currentLine.isEmpty ? word : '$currentLine $word';
        final lineWidth = columnFont.getMetrics(testLine).width;
        if (lineWidth <= columnWidth) {
          currentLine = testLine;
        } else {
          if (currentLine.isNotEmpty) {
            lineCount++;
          }
          currentLine = word;
        }
      }
      if (currentLine.isNotEmpty) {
        lineCount++;
      }
      if (lineCount == 0) {
        lineCount = 1;
      }
      if (maxLines < lineCount) {
        maxLines = lineCount;
      }
    }

    final font = _resolveFont(command.columns.first.style);
    final lineHeight = font.lineHeight.toInt();
    return (maxLines * lineHeight) + (lineHeight ~/ 12);
  }

  int _estimateLineHeight(int thickness) => 5 + thickness + 10;

  int _estimateFeedHeight(int lines) {
    final feedFont = _resolveFont(style);
    final lineHeight = feedFont.lineHeight.toInt();
    return (lineHeight + 10) * lines;
  }

  /// Execute all queued operations in an isolate and return the PNG bytes.
  ///
  /// Runs all drawing operations in a background isolate to keep UI responsive.
  Future<Uint8List> build() async {
    // Use the running estimate with a 20% buffer to minimize resizing
    final initialHeight =
        _estimatedHeight > 0 ? (_estimatedHeight * 1.2).round() : null;

    final commands = List<_DrawCommand>.from(_commandQueue);
    final paperSizeCopy = paperSize;
    final marginCopy = margin;
    final styleCopy = style;

    return await Isolate.run(() {
      final util = GraphicsPrintUtilsBitmap(
        paperSize: paperSizeCopy,
        margin: marginCopy,
        style: styleCopy,
        initialHeight: initialHeight,
      );

      for (final command in commands) {
        command.execute(util);
      }

      return util.build();
    });
  }

  /// Clear all queued commands
  void clear() {
    _commandQueue.clear();
    _estimatedHeight = 0;
  }

  /// Get the number of queued commands
  int get commandCount => _commandQueue.length;
}
