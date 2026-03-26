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
