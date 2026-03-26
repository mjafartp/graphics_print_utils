# Monochrome Receipt Renderer — Design Spec

**Date:** 2026-03-26
**Version:** 2.0.0
**Status:** Approved

## Problem

The current receipt image generator has performance and output size issues:

1. Renders to RGBA (4 bytes/pixel), then PNG encodes — both unnecessary since the target is 1-bit B&W thermal printers
2. Two-phase compositing: Canvas text → `img.Image` pixel copy → composite with QR/barcode/line `img.Image` buffers → PNG encode
3. PNG encoding is the single biggest bottleneck (~50-150ms for a typical receipt, 500ms+ for large ones)
4. Output size too large for Bluetooth printer buffers (50-200KB PNG vs ~108KB monochrome)
5. Four parallel classes create maintenance burden and prevent focused optimization

## Objective

- Typical receipt (30 lines + QR): **under 100ms** build time
- Large receipts (100+ lines): proportionally fast (no super-linear scaling)
- Output: raw 1-bit monochrome bytes, ready for ESC/POS raster commands
- Minimal output size for fast Bluetooth transfer
- Single class, clean API

## Architecture

### Pipeline

```
Queue ops (sync) → Measure total height → Paint ALL ops on ONE Canvas → toByteData(rawRgba) → Threshold to 1-bit packed bytes → Return MonochromeImage
```

### What This Eliminates

- `img.Image` creation and pixel-by-pixel copy loops
- `img.compositeImage()` calls for QR, barcode, images
- `img.fillRect()` for lines/dotted lines
- `img.encodePng()` — the biggest bottleneck
- Separate `FlutterTextRenderer.renderText()` method
- All bitmap font files
- The entire bitmap renderer class

### Single Class: `GraphicsPrintUtils`

One class with a command-queue pattern. All operations are synchronous (they just queue). Only `build()` is async.

## API

```dart
final receipt = GraphicsPrintUtils(paperSize: PrintPaperSize.mm80);

// All sync — just queue operations
receipt.text('Hello World', style: PrintTextStyle(bold: true));
receipt.row(columns: [
  PrintColumn(text: 'Item', flex: 3),
  PrintColumn(text: '10.00', flex: 1, style: PrintTextStyle(align: PrintAlign.right)),
]);
receipt.line();
receipt.dottedLine();
receipt.qr('https://example.com');
receipt.barcode('12345', barcode: Barcode.code128());
receipt.image(someImage);
receipt.feed(lines: 2);

// Build — only async call, returns monochrome bitmap
final result = await receipt.build(); // MonochromeImage
```

### API Changes from Current

| Current | New | Reason |
|---------|-----|--------|
| `text()` returns `Future<void>` | `text()` is `void` | Only queues, nothing async |
| `row()` returns `Future<void>` | `row()` is `void` | Only queues, nothing async |
| `build()` returns `Uint8List` (PNG) | `build()` returns `MonochromeImage` | Raw 1-bit bytes + dimensions |
| 4 classes | 1 class `GraphicsPrintUtils` | Single optimized path |

### Output Type

```dart
class MonochromeImage {
  final Uint8List bytes;  // packed 1-bit, MSB first, 8 pixels per byte
  final int width;        // pixels (padded to multiple of 8)
  final int height;       // pixels
}
```

- Width padded to multiple of 8 (ESC/POS raster commands require byte-aligned rows)
- MSB first: standard ESC/POS bit ordering
- Each row = `width / 8` bytes
- Total bytes = `(width / 8) * height`

## Build Pipeline Detail

### Step 1: Measure

Iterate all queued ops. Use `TextPainter.layout()` to get heights. Sum to get total receipt height. Same approach as current — this is fast (~5ms).

### Step 2: Paint Everything on ONE Canvas

Create a single `PictureRecorder` + `Canvas`. Paint all operations:

- **Text/Row:** `TextPainter.paint()` directly on Canvas (same as current batch approach)
- **Lines:** `canvas.drawRect()` with black paint
- **Dotted lines:** Loop of `canvas.drawRect()` calls
- **QR codes:** Use `qr` package for matrix, `canvas.drawRect()` per dark module
- **Barcodes:** Use `barcode` package base (`Barcode.make()` returns bar elements), `canvas.drawRect()` per bar
- **Images:** Convert input `img.Image` → `ui.Image` via `decodeImageFromPixels()`, draw with `canvas.drawImage()`
- **Feed:** Just advance Y position (white space)

White background painted first via `canvas.drawRect()` covering full dimensions.

### Step 3: Extract RGBA Pixels

```dart
final picture = recorder.endRecording();
final uiImage = picture.toImageSync(width, height);
final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
```

### Step 4: Threshold to 1-Bit

Single pass through RGBA bytes. For each pixel:

```dart
final luminance = (pixels[i] + pixels[i + 1] + pixels[i + 2]) ~/ 3;
final bit = luminance < 128 ? 1 : 0;  // black = 1, white = 0
```

Pack 8 pixels per byte, MSB first:

```dart
final bytesPerRow = width ~/ 8;
final monoBytes = Uint8List(bytesPerRow * height);
for (int y = 0; y < height; y++) {
  for (int byteX = 0; byteX < bytesPerRow; byteX++) {
    int byte = 0;
    for (int bit = 0; bit < 8; bit++) {
      final x = byteX * 8 + bit;
      final i = (y * width + x) * 4;
      final luminance = (pixels[i] + pixels[i + 1] + pixels[i + 2]) ~/ 3;
      if (luminance < 128) {
        byte |= (0x80 >> bit);
      }
    }
    monoBytes[y * bytesPerRow + byteX] = byte;
  }
}
```

### Step 5: Return MonochromeImage

Dispose `uiImage` and `picture`, return `MonochromeImage(bytes: monoBytes, width: width, height: height)`.

## QR Code Rendering (Canvas-native)

```dart
void _paintQr(Canvas canvas, String data, int qrSize, int x, int y) {
  final qrCode = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
  final qrImage = QrImage(qrCode);
  final moduleCount = qrImage.moduleCount;
  final pixelSize = (qrSize / moduleCount).floor();
  final paint = Paint()..color = const Color(0xFF000000);

  for (int row = 0; row < moduleCount; row++) {
    for (int col = 0; col < moduleCount; col++) {
      if (qrImage.isDark(col, row)) {
        canvas.drawRect(
          Rect.fromLTWH(
            (x + col * pixelSize).toDouble(),
            (y + row * pixelSize).toDouble(),
            pixelSize.toDouble(),
            pixelSize.toDouble(),
          ),
          paint,
        );
      }
    }
  }
}
```

## Barcode Rendering (Canvas-native)

Replace `barcode_image` dependency with base `barcode` package:

```dart
void _paintBarcode(Canvas canvas, Barcode barcode, String data, int width, int height, int x, int y) {
  final elements = barcode.make(data, width: width.toDouble(), height: height.toDouble());
  final paint = Paint()..color = const Color(0xFF000000);

  for (final element in elements) {
    if (element is BarcodeBar && element.black) {
      canvas.drawRect(
        Rect.fromLTWH(x + element.left, y + element.top, element.width, element.height),
        paint,
      );
    }
  }
}
```

## User-Supplied Image Handling

Accept `img.Image` input (maintains API compatibility), convert to `ui.Image` for Canvas drawing:

```dart
Future<ui.Image> _imgToUiImage(img.Image image) async {
  final rgba = image.getBytes(order: img.ChannelOrder.rgba);
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba, image.width, image.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
```

Draw on Canvas with `canvas.drawImageRect()` for resize support.

## Dependencies

| Current | New | Reason |
|---------|-----|--------|
| `image: ^4.8.0` | Keep | User-supplied image input conversion |
| `qr: ^3.0.2` | Keep | QR matrix generation |
| `barcode_image: ^2.0.3` | Replace with `barcode: ^2.0.3` | Draw bars on Canvas directly, no `image` dependency needed |

## Files to Remove

- `lib/resources/graphics_print_utils_manager.dart` — bitmap renderer
- `lib/resources/graphics_print_utils_manager_command_based.dart` — command-based wrappers
- `lib/fonts/` — all bitmap font files
- `FlutterTextRenderer.renderText()` — no longer needed (keep `measureHeight`, `measureWidth`, `detectDirection`, `getFontSize`)

## Files to Modify

- `lib/resources/graphics_print_utils_canvas.dart` — rewrite with monochrome pipeline
- `lib/resources/flutter_text_renderer.dart` — remove `renderText()`, keep measurement utilities
- `lib/graphics_print.dart` — update exports (single class + supporting types)
- `pubspec.yaml` — replace `barcode_image` with `barcode`

## Files to Create

- None — all changes go into existing files

## Performance Budget

**Typical receipt (30 lines + QR, 576x1500px):**

| Step | Time |
|------|------|
| Measure heights | ~5ms |
| Paint on Canvas | ~20ms |
| `toByteData()` | ~10ms |
| Threshold to 1-bit | ~5ms |
| **Total** | **~40ms** |

**vs current: ~120-220ms (3-5x improvement)**

**Output size (576x1500px):**

| Format | Size |
|--------|------|
| Current PNG | 50-200KB |
| New monochrome 1-bit | ~108KB |

For Bluetooth: 1-bit data is ready to send directly to ESC/POS raster commands — no decode step on printer side.

## Edge Cases

- **Empty build:** If `build()` is called with zero ops, return a `MonochromeImage` with 1px height, all white (zero bytes).
- **Width not multiple of 8:** Paper widths (576px for 80mm, 384px for 58mm) are already multiples of 8. If a custom width isn't, pad to the next multiple of 8.
- **`image()` input:** The `image` package remains a public dependency since `image()` accepts `img.Image`. This is acceptable — users already depend on it for image loading.

## Kept As-Is

- `PrintTextStyle`, `PrintColumn`, `PrintPaperSize`, `PrintMargin`, `PrintAlign`, `PrintFontSize` — all enums/value types unchanged
- `FlutterTextRenderer.measureHeight()`, `measureWidth()`, `detectDirection()`, `getFontSize()` — measurement utilities
- Arabic shaping support via `ShapeArabic`
- RTL detection and handling
