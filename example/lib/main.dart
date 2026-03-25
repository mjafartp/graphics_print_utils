import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart' hide Barcode;
import 'package:graphics_print_utils/graphics_print.dart';
import 'package:image/image.dart' as img;

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
  bool _isPrinting = false;
  BuildContext? _scaffoldContext;
  final _ipController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '9100');

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
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

  Future<void> _printViaNetwork() async {
    if (_pngImage.isEmpty || _isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final decoded = img.decodePng(_pngImage);
      if (decoded == null) {
        if (mounted && _scaffoldContext != null) _showSnackBar(_scaffoldContext!, 'Failed to decode image');
        return;
      }

      List<int> bytes = generator.image(decoded);
      bytes += generator.cut();

      final host = _ipController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 9100;
      final printer = PrinterNetworkManager(host, port: port);

      final result = await printer.printTicket(bytes);
      if (mounted && _scaffoldContext != null) {
        _showSnackBar(_scaffoldContext!, result == PosPrintResult.success
            ? 'Printed to $host:$port'
            : 'Error: ${result.msg}');
      }
    } catch (e) {
      if (mounted && _scaffoldContext != null) _showSnackBar(_scaffoldContext!, 'Print error: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showSnackBar(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPrinterDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: const Text('Network Printer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                  labelText: 'IP Address', hintText: '192.168.1.100'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              decoration:
                  const InputDecoration(labelText: 'Port', hintText: '9100'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _printViaNetwork();
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graphics Print Utils',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: Builder(builder: (context) {
        _scaffoldContext = context;
        return Scaffold(
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
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: _isPrinting ? null : () => _showPrinterDialog(context),
            icon: _isPrinting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print),
            label: Text(_isPrinting ? 'Printing...' : 'Print via Network'),
          ),
        ),
      );
      }),
    );
  }
}

/// Draws a sample receipt using GraphicsPrintUtils (Flutter Canvas).
/// Full Unicode support — all languages render correctly.
Future<Uint8List> _drawReceipt() async {
  final g = GraphicsPrintUtils(
    paperSize: PrintPaperSize.mm80,
    margin: const PrintMargin(left: 10, right: 10),
  );

  g.feed(lines: 1);

  // Header
  await g.text('SuperMart',
      style: const PrintTextStyle(
          fontSize: PrintFontSize.large, align: PrintAlign.center, bold: true));
  await g.text('123 Main Street, City',
      style: const PrintTextStyle(fontSize: PrintFontSize.small, align: PrintAlign.center));
  await g.text('Tel: (123) 456-7890',
      style: const PrintTextStyle(fontSize: PrintFontSize.small, align: PrintAlign.center));

  g.line();

  // Column header
  await g.row(columns: [
    PrintColumn('Item', flex: 4, style: const PrintTextStyle(bold: true)),
    PrintColumn('Qty', flex: 1, style: const PrintTextStyle(align: PrintAlign.right, bold: true)),
    PrintColumn('Price', flex: 2, style: const PrintTextStyle(align: PrintAlign.right, bold: true)),
  ], spacing: 10);

  g.line();

  // Multi-language items
  await g.row(columns: [
    PrintColumn('Espresso', flex: 4),
    PrintColumn('2', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$6.00', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  g.dottedLine();

  await g.row(columns: [
    PrintColumn('Crème brûlée', flex: 4),
    PrintColumn('1', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$4.50', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  g.dottedLine();

  await g.row(columns: [
    PrintColumn('珍珠奶茶', flex: 4),
    PrintColumn('3', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$15.00', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  g.dottedLine();

  await g.row(columns: [
    PrintColumn('抹茶ラテ', flex: 4),
    PrintColumn('4', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$10.00', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  g.dottedLine();

  await g.row(columns: [
    PrintColumn('달고나 커피', flex: 4),
    PrintColumn('1', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$5.50', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  g.dottedLine();

  await g.row(columns: [
    PrintColumn('قهوة عربي', flex: 4),
    PrintColumn('2', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$7.00', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  g.dottedLine();

  await g.row(columns: [
    PrintColumn('چای ایرانی', flex: 4),
    PrintColumn('3', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$6.00', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  g.dottedLine();

  await g.row(columns: [
    PrintColumn('मसाला चाय', flex: 4),
    PrintColumn('1', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$6.00', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  g.dottedLine();

  await g.row(columns: [
    PrintColumn('ชาเย็น', flex: 4),
    PrintColumn('2', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$8.50', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  g.dottedLine();

  await g.row(columns: [
    PrintColumn('കള്ള്', flex: 4),
    PrintColumn('2', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$8.50', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  g.dottedLine();

  await g.row(columns: [
    PrintColumn('Блины', flex: 4),
    PrintColumn('1', flex: 1, style: const PrintTextStyle(align: PrintAlign.right)),
    PrintColumn('\$4.75', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);

  g.line();

  // Totals
  await g.row(columns: [
    PrintColumn('Subtotal', flex: 6),
    PrintColumn('\$73.25', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  await g.row(columns: [
    PrintColumn('Tax (8.5%)', flex: 6),
    PrintColumn('\$6.23', flex: 2, style: const PrintTextStyle(align: PrintAlign.right)),
  ], spacing: 10);
  await g.row(columns: [
    PrintColumn('Total', flex: 6, style: const PrintTextStyle(bold: true)),
    PrintColumn('\$79.48', flex: 2, style: const PrintTextStyle(align: PrintAlign.right, bold: true)),
  ], spacing: 10);

  g.line();

  // QR + Barcode
  await g.text('Scan for Receipt', style: const PrintTextStyle(align: PrintAlign.center));
  g.qr('https://example.com/receipt/12345');
  await g.text('Scan for invoice', style: const PrintTextStyle(align: PrintAlign.center));
  g.barcode('1259854', barcode: Barcode.code128());

  g.line();

  // Multi-language footer — all scripts rendered by Flutter Canvas
  await g.text('Thank you for shopping!', style: const PrintTextStyle(align: PrintAlign.center));
  await g.text('Merci pour vos achats !', style: const PrintTextStyle(align: PrintAlign.center));
  await g.text('مرحباً بالعالم', style: const PrintTextStyle(align: PrintAlign.center));
  await g.text('谢谢光临', style: const PrintTextStyle(align: PrintAlign.center));
  await g.text('ありがとうございます', style: const PrintTextStyle(align: PrintAlign.center));
  await g.text('감사합니다', style: const PrintTextStyle(align: PrintAlign.center));
  await g.text('Спасибо за покупку!', style: const PrintTextStyle(align: PrintAlign.center));
  await g.text('ขอบคุณครับ', style: const PrintTextStyle(align: PrintAlign.center));
  await g.text('धन्यवाद', style: const PrintTextStyle(align: PrintAlign.center));

  g.feed(lines: 1);

  return g.build();
}
