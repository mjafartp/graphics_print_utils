import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart' hide Barcode;
import 'package:graphics_print_utils/graphics_print.dart';
import 'package:image/image.dart' as img;
import 'package:receipt_builder/receipt_builder.dart';
import 'package:receipt_builder/backends/graphics_backend.dart';
import 'package:receipt_builder/backends/esc_pos_backend.dart';

/// Build the shared receipt — defined ONCE, used by both backends.
Receipt _buildDemoReceipt() {
  return Receipt()
      // ── HEADER ──
      .text('LITHOS CAFE',
          style: const RStyle(
              bold: true, size: RSize.x3, align: RAlign.center))
      .text('Premium Coffee & Bakery',
          style: const RStyle(align: RAlign.center))
      .text('123 Innovation Blvd, Suite 400',
          style: const RStyle(align: RAlign.center))
      .text('Tel: (555) 012-3456',
          style: const RStyle(align: RAlign.center))
      .divider()
      // ── RECEIPT INFO ──
      .row([
        const RCol('Receipt #:', flex: 1, bold: true),
        const RCol('INV-2026-03847', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('Date:', flex: 1, bold: true),
        const RCol('2026-03-25 14:32', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('Cashier:', flex: 1, bold: true),
        const RCol('Jafar M.', flex: 2, align: RAlign.right),
      ])
      .divider()
      // ── COLUMN HEADER ──
      .row([
        const RCol('ITEM', flex: 4, bold: true),
        const RCol('QTY', flex: 1, align: RAlign.right, bold: true),
        const RCol('PRICE', flex: 2, align: RAlign.right, bold: true),
      ])
      .divider()
      // ── 15 ITEMS (multi-language, native scripts) ──
      .row([
        const RCol('Espresso', flex: 4),
        const RCol('2', flex: 1, align: RAlign.right),
        const RCol('\$6.00', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('Crème brûlée', flex: 4),
        const RCol('1', flex: 1, align: RAlign.right),
        const RCol('\$4.50', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('珍珠奶茶', flex: 4),
        const RCol('3', flex: 1, align: RAlign.right),
        const RCol('\$15.00', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('Café con leña', flex: 4),
        const RCol('2', flex: 1, align: RAlign.right),
        const RCol('\$7.50', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('Käsekuchen', flex: 4),
        const RCol('1', flex: 1, align: RAlign.right),
        const RCol('\$6.50', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('Türk Kahvesi', flex: 4),
        const RCol('2', flex: 1, align: RAlign.right),
        const RCol('\$8.00', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('抹茶ラテ', flex: 4),
        const RCol('4', flex: 1, align: RAlign.right),
        const RCol('\$10.00', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('달고나 커피', flex: 4),
        const RCol('1', flex: 1, align: RAlign.right),
        const RCol('\$5.50', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('قهوة عربي', flex: 4),
        const RCol('2', flex: 1, align: RAlign.right),
        const RCol('\$7.00', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('چای ایرانی', flex: 4),
        const RCol('3', flex: 1, align: RAlign.right),
        const RCol('\$6.00', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('मसाला चाय', flex: 4),
        const RCol('1', flex: 1, align: RAlign.right),
        const RCol('\$6.00', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('ชาเย็น', flex: 4),
        const RCol('2', flex: 1, align: RAlign.right),
        const RCol('\$8.50', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('Блины', flex: 4),
        const RCol('1', flex: 1, align: RAlign.right),
        const RCol('\$4.75', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('Pão de queijo', flex: 4),
        const RCol('3', flex: 1, align: RAlign.right),
        const RCol('\$7.50', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('鳳梨酥', flex: 4),
        const RCol('2', flex: 1, align: RAlign.right),
        const RCol('\$6.50', flex: 2, align: RAlign.right),
      ])
      .divider()
      // ── TOTALS ──
      .row([
        const RCol('Subtotal:', flex: 2, align: RAlign.right),
        const RCol('\$109.25', flex: 1, align: RAlign.right),
      ])
      .row([
        const RCol('Discount (10%):', flex: 2, align: RAlign.right),
        const RCol('-\$10.93', flex: 1, align: RAlign.right),
      ])
      .row([
        const RCol('Tax (8.5%):', flex: 2, align: RAlign.right),
        const RCol('\$8.36', flex: 1, align: RAlign.right),
      ])
      .divider()
      .text('TOTAL: \$106.68',
          style: const RStyle(
              bold: true, size: RSize.x2, align: RAlign.center))
      .divider()
      // ── PAYMENT ──
      .row([
        const RCol('Payment:', flex: 1, bold: true),
        const RCol('Visa **** 4242', flex: 2, align: RAlign.right),
      ])
      .row([
        const RCol('Auth Code:', flex: 1, bold: true),
        const RCol('A7F93B', flex: 2, align: RAlign.right),
      ])
      .divider()
      // ── QR + BARCODE ──
      .text('Scan for Receipt',
          style: const RStyle(align: RAlign.center))
      .qrcode('https://example.com/receipt/12345', size: 5)
      .barcode('1259854', type: RBarcodeType.code128)
      // ── FOOTER ──
      .divider()
      .text('Thank you for shopping!',
          style: const RStyle(align: RAlign.center))
      .text('receipt_builder demo',
          style: const RStyle(align: RAlign.center))
      .feed(2)
      .cut();
}

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
  final _ipController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '9100');

  @override
  void initState() {
    super.initState();
    _generatePreview();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _generatePreview() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final receipt = _buildDemoReceipt();

      // GraphicsBackend: Receipt → PNG image (for preview & image-based printing)
      final pngBytes = GraphicsBackend(
        paperSize: PrintPaperSize.mm80,
        margin: const PrintMargin(left: 10, right: 10),
      ).generate(receipt);

      setState(() => _pngImage = pngBytes);
    } catch (e) {
      debugPrint('Error generating preview: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printViaNetwork(BuildContext context) async {
    if (_pngImage.isEmpty || _isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      // Convert the PNG preview image to ESC/POS bytes for network printer
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final decodedImage = img.decodeImage(_pngImage);
      if (decodedImage == null) {
        if (context.mounted) _showSnackBar(context, 'Failed to decode image');
        return;
      }
      List<int> bytes = generator.image(decodedImage);
      bytes += generator.cut();

      // Send to network printer
      final host = _ipController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 9100;
      final printer = PrinterNetworkManager(host, port: port);

      final connectResult = await printer.connect();
      if (!context.mounted) return;
      if (connectResult == PosPrintResult.success) {
        final printResult = await printer.printTicket(bytes);
        if (context.mounted) _showSnackBar(context, printResult.msg);
      } else {
        _showSnackBar(context, connectResult.msg);
      }
    } catch (e) {
      if (context.mounted) _showSnackBar(context, 'Print error: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _printEscPosViaNetwork(BuildContext context) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final receipt = _buildDemoReceipt();

      // EscPosBackend: Receipt → ESC/POS bytes directly (no image step)
      final profile = await CapabilityProfile.load();
      final bytes = EscPosBackend(
        paperSize: PaperSize.mm80,
        profile: profile,
      ).generate(receipt);

      // Send to network printer
      final host = _ipController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 9100;
      final printer = PrinterNetworkManager(host, port: port);

      final connectResult = await printer.connect();
      if (!context.mounted) return;
      if (connectResult == PosPrintResult.success) {
        final printResult = await printer.printTicket(bytes);
        if (context.mounted) _showSnackBar(context, printResult.msg);
      } else {
        if (context.mounted) _showSnackBar(context, connectResult.msg);
      }
    } catch (e) {
      if (context.mounted) _showSnackBar(context, 'Print error: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showPrinterDialog(BuildContext context, {required bool useGraphics}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(useGraphics ? 'Print as Image' : 'Print as ESC/POS'),
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
              decoration: const InputDecoration(
                  labelText: 'Port', hintText: '9100'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (useGraphics) {
                _printViaNetwork(context);
              } else {
                _printEscPosViaNetwork(context);
              }
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
      title: 'Receipt Builder — Graphics + Network',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Receipt Builder Demo'),
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
                  onPressed: _generatePreview,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Regenerate preview',
                ),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Same Receipt() → two backends',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    )
                  else if (_pngImage.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.memory(_pngImage),
                    )
                  else
                    const Text('No preview'),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting
                        ? null
                        : () =>
                            _showPrinterDialog(context, useGraphics: true),
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image),
                    label: const Text('Image Print'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting
                        ? null
                        : () =>
                            _showPrinterDialog(context, useGraphics: false),
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print),
                    label: const Text('ESC/POS Print'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
