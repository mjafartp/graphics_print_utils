import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:graphics_print_utils/graphics_print.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Uint8List _pngImage = Uint8List.fromList([]);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final bytes = await _drawReceipt();
      if (mounted) setState(() => _pngImage = bytes);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graphics Print Utils',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Graphics Print Utils'),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              IconButton(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                tooltip: 'Regenerate',
              ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  )
                : _pngImage.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.memory(_pngImage),
                      )
                    : const Text('No preview'),
          ),
        ),
      ),
    );
  }
}

/// Draws a sample receipt using GraphicsPrintUtils directly.
/// This demonstrates the graphics_print_utils API — text, rows,
/// lines, QR codes, barcodes, and multi-language support.
Future<Uint8List> _drawReceipt() async {
  final g = GraphicsPrintUtils(
    paperSize: PrintPaperSize.mm80,
    margin: const PrintMargin(left: 10, right: 10),
  );

  g.feed(lines: 1);

  // Header
  g.text('SuperMart',
      style: const PrintTextStyle(
          fontSize: PrintFontSize.large,
          align: PrintAlign.center,
          bold: true));
  g.text('123 Main Street, City',
      style: const PrintTextStyle(
          fontSize: PrintFontSize.small, align: PrintAlign.center));
  g.text('Tel: (123) 456-7890',
      style: const PrintTextStyle(
          fontSize: PrintFontSize.small, align: PrintAlign.center));

  g.line();

  // Column header
  g.row(columns: [
    PrintColumn('Item', flex: 4, style: const PrintTextStyle(bold: true)),
    PrintColumn('Qty',
        flex: 1,
        style: const PrintTextStyle(align: PrintAlign.right, bold: true)),
    PrintColumn('Price',
        flex: 2,
        style: const PrintTextStyle(align: PrintAlign.right, bold: true)),
  ], spacing: 10);

  g.line();

  // Items
  g.row(columns: [
    PrintColumn('Apples', flex: 4),
    PrintColumn('2',
        flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$3.00',
        flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);

  g.dottedLine();

  g.row(columns: [
    PrintColumn('قيمة', flex: 4),
    PrintColumn('2',
        flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$3.00',
        flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);

  g.dottedLine();

  g.row(columns: [
    PrintColumn('Bananas', flex: 4),
    PrintColumn('1',
        flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$1.50',
        flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);

  g.dottedLine();

  g.row(columns: [
    PrintColumn('Milk', flex: 4),
    PrintColumn('1',
        flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$2.50',
        flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);

  g.line();

  // Totals
  g.row(columns: [
    PrintColumn('Subtotal', flex: 6),
    PrintColumn('\$7.00',
        flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);

  g.row(columns: [
    PrintColumn('Tax', flex: 6),
    PrintColumn('\$0.50',
        flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);

  g.row(columns: [
    PrintColumn('Total',
        flex: 6, style: const PrintTextStyle(bold: true)),
    PrintColumn('\$7.50',
        flex: 2,
        style: const PrintTextStyle(align: PrintAlign.right, bold: true)),
  ], spacing: 10);

  g.line();

  // QR + Barcode
  g.text('Scan for Receipt',
      style: const PrintTextStyle(align: PrintAlign.center));
  g.qr('https://example.com/receipt/12345');

  g.text('Scan for invoice',
      style: const PrintTextStyle(align: PrintAlign.center));
  g.barcode('1259854', barcode: Barcode.code128());

  g.line();

  // Multi-language footer
  g.text('Thank you for shopping!',
      style: const PrintTextStyle(align: PrintAlign.center));
  g.text('مرحباً بالعالم',
      style: const PrintTextStyle(align: PrintAlign.center));
  g.text('السلام عليكم',
      style: const PrintTextStyle(align: PrintAlign.center));

  g.feed(lines: 1);

  return g.build();
}
