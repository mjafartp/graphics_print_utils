import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart' hide Barcode;
import 'package:graphics_print_utils/graphics_print.dart';
import 'package:image/image.dart' as img;

// Top-level function for isolate execution - runs drawing in background
Uint8List _drawEscImageInBackground() {
  final now1 = DateTime.now();
  GraphicsPrintUtils escImageUtil = GraphicsPrintUtils(
    paperSize: PrintPaperSize.mm80,
    margin: PrintMargin(left: 10, right: 10),
  );

  // All drawing operations - runs in background isolate, UI stays responsive!
  // Add store name and header
  escImageUtil.feed(lines: 1);
  escImageUtil.text(
    "SuperMart",
    style: PrintTextStyle(
      fontSize: PrintFontSize.large,
      align: PrintAlign.center,
      bold: true,
    ),
  );
  escImageUtil.text(
    "123 Main Street, Suite 456, Building 7, Business District, City, State, ZIP, Country, Near Central Park, Opposite to ABC Mall, Landmark XYZ",
    style: PrintTextStyle(
      fontSize: PrintFontSize.small,
      align: PrintAlign.center,
    ),
  );
  escImageUtil.text(
    "City, State, ZIP",
    style: PrintTextStyle(
      fontSize: PrintFontSize.small,
      align: PrintAlign.center,
    ),
  );
  escImageUtil.text(
    "Tel: (123) 456-7890",
    style: PrintTextStyle(
      fontSize: PrintFontSize.small,
      align: PrintAlign.center,
    ),
  );

  escImageUtil.line();

  // Add itemized list
  escImageUtil.row(
    columns: [
      PrintColumn('Item', flex: 4),
      PrintColumn(
        'Qty',
        flex: 1,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
      PrintColumn(
        'Price',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.line();
  escImageUtil.row(
    columns: [
      PrintColumn('Apples', flex: 4),
      PrintColumn(
        '2',
        flex: 1,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
      PrintColumn(
        '\$3.00',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.dottedLine();
  escImageUtil.row(
    columns: [
      PrintColumn('قيمة', flex: 4),
      PrintColumn(
        '2',
        flex: 1,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
      PrintColumn(
        '\$3.00',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.dottedLine();
  escImageUtil.row(
    columns: [
      PrintColumn('Bananas  ', flex: 4),
      PrintColumn(
        '1',
        flex: 1,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
      PrintColumn(
        '\$1.50',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.dottedLine();
  escImageUtil.row(
    columns: [
      PrintColumn('Milk', flex: 4),
      PrintColumn(
        '1',
        flex: 1,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
      PrintColumn(
        '\$2.50',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.line();

  // Add totals
  escImageUtil.row(
    columns: [
      PrintColumn('Subtotal', flex: 6),
      PrintColumn(
        '\$7.00',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.row(
    columns: [
      PrintColumn('Tax', flex: 6),
      PrintColumn(
        '\$0.50',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.row(
    columns: [
      PrintColumn('Total', flex: 6, style: PrintTextStyle(bold: true)),
      PrintColumn(
        '\$7.50',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right, bold: true),
      ),
    ],
    spacing: 10,
  );

  escImageUtil.line();

  // Add QR code for receipt verification
  escImageUtil.text(
    "Scan for Receipt",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.qr('https://example.com/receipt/12345');

  escImageUtil.text(
    "Scan for invoice",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.barcode('1259854', barcode: Barcode.code128());

  // Add footer
  escImageUtil.text(
    "Thank you for shopping!",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "Visit us again!",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "¡Gracias por comprar con nosotros!",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "Merci pour vos achats !",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "Bedankt voor uw aankoop!",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "   السلام عليكم  ",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "مرحباً بالعالم",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "قيمة",
    style: PrintTextStyle(align: PrintAlign.right),
  );

  escImageUtil.feed(lines: 1);

  var bytes = escImageUtil.build();
  final now2 = DateTime.now();
  debugPrint("*******************total time ${now2.difference(now1)}");
  return bytes;
}

// Command-based function for isolate execution - prepares all operations first, then draws in background
Future<Uint8List> _drawEscImageInBackgroundCommandBased() async {
  final now1 = DateTime.now();
  GraphicsPrintUtilsCommandBased escImageUtil = GraphicsPrintUtilsCommandBased(
    paperSize: PrintPaperSize.mm80,
    margin: PrintMargin(left: 10, right: 10),
  );

  // All drawing operations - prepare all commands synchronously (no isolate yet)
  // Add store name and header
  escImageUtil.feed(lines: 1);
  escImageUtil.text(
    "SuperMart",
    style: PrintTextStyle(
      fontSize: PrintFontSize.large,
      align: PrintAlign.center,
      bold: true,
    ),
  );
  escImageUtil.text(
    "123 Main Street, Suite 456, Building 7, Business District, City, State, ZIP, Country, Near Central Park, Opposite to ABC Mall, Landmark XYZ",
    style: PrintTextStyle(
      fontSize: PrintFontSize.small,
      align: PrintAlign.center,
    ),
  );
  escImageUtil.text(
    "City, State, ZIP",
    style: PrintTextStyle(
      fontSize: PrintFontSize.small,
      align: PrintAlign.center,
    ),
  );
  escImageUtil.text(
    "Tel: (123) 456-7890",
    style: PrintTextStyle(
      fontSize: PrintFontSize.small,
      align: PrintAlign.center,
    ),
  );

  escImageUtil.line();

  // Add itemized list
  escImageUtil.row(
    columns: [
      PrintColumn('Item', flex: 4),
      PrintColumn(
        'Qty',
        flex: 1,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
      PrintColumn(
        'Price',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.line();
  escImageUtil.row(
    columns: [
      PrintColumn('Apples', flex: 4),
      PrintColumn(
        '2',
        flex: 1,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
      PrintColumn(
        '\$3.00',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.dottedLine();
  escImageUtil.row(
    columns: [
      PrintColumn('قيمة', flex: 4),
      PrintColumn(
        '2',
        flex: 1,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
      PrintColumn(
        '\$3.00',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.dottedLine();
  escImageUtil.row(
    columns: [
      PrintColumn('Bananas  ', flex: 4),
      PrintColumn(
        '1',
        flex: 1,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
      PrintColumn(
        '\$1.50',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.dottedLine();
  escImageUtil.row(
    columns: [
      PrintColumn('Milk', flex: 4),
      PrintColumn(
        '1',
        flex: 1,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
      PrintColumn(
        '\$2.50',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.line();

  // Add totals
  escImageUtil.row(
    columns: [
      PrintColumn('Subtotal', flex: 6),
      PrintColumn(
        '\$7.00',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.row(
    columns: [
      PrintColumn('Tax', flex: 6),
      PrintColumn(
        '\$0.50',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right),
      ),
    ],
    spacing: 10,
  );
  escImageUtil.row(
    columns: [
      PrintColumn('Total', flex: 6, style: PrintTextStyle(bold: true)),
      PrintColumn(
        '\$7.50',
        flex: 2,
        style: PrintTextStyle(align: PrintAlign.right, bold: true),
      ),
    ],
    spacing: 10,
  );

  escImageUtil.line();

  // Add QR code for receipt verification
  escImageUtil.text(
    "Scan for Receipt",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.qr('https://example.com/receipt/12345');

  escImageUtil.text(
    "Scan for invoice",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.barcode('1259854', barcode: Barcode.code128());

  // Add footer
  escImageUtil.text(
    "Thank you for shopping!",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "Visit us again!",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "¡Gracias por comprar con nosotros!",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "Merci pour vos achats !",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "Bedankt voor uw aankoop!",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "   السلام عليكم  ",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "مرحباً بالعالم",
    style: PrintTextStyle(align: PrintAlign.center),
  );
  escImageUtil.text(
    "قيمة",
    style: PrintTextStyle(align: PrintAlign.right),
  );

  final bytes = await escImageUtil.build();
  final now2 = DateTime.now();
  debugPrint("*******************total time ${now2.difference(now1)}");

  return bytes;
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
  Uint8List pngImage = Uint8List.fromList([]);
  int count = 0;
  bool _isLoading = false;
  bool _isPrinting = false;
  final _ipController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '9100');

  @override
  void initState() {
    initialize();
    super.initState();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      pngImage = await _drawEscImageInBackgroundCommandBased();
    } catch (e) {
      debugPrint("Error drawing image: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> initialize1() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      pngImage = _drawEscImageInBackground();
    } catch (e) {
      debugPrint("Error drawing image: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _printToNetworkPrinter(BuildContext context) async {
    if (pngImage.isEmpty || _isPrinting) return;

    setState(() {
      _isPrinting = true;
    });

    try {
      // Generate ESC/POS bytes from the rendered image
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final decodedImage = img.decodeImage(pngImage);
      if (decodedImage == null) {
        if (context.mounted) _showSnackBar(context, 'Failed to decode image');
        return;
      }
      List<int> bytes = generator.image(decodedImage);
      bytes += generator.cut();

      // Connect and print via network
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
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showPrinterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Network Printer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.100',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '9100',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _printToNetworkPrinter(context);
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
      home: Builder(builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app', style: TextStyle()),
          actions: [
            if (_isLoading)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: initialize1,
                icon: Icon(Icons.refresh),
              ),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: initialize,
                icon: Icon(Icons.refresh),
              ),
            IconButton(
              onPressed: () {
                setState(() {
                  count++;
                });
              },
              icon: Icon(Icons.add),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text('Count: $count'),
                if (_isLoading)
                  Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  Builder(
                    builder: (context) {
                      if (pngImage.isEmpty) {
                        return SizedBox();
                      } else {
                        return Image.memory(pngImage);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final profile = await CapabilityProfile.load();
                    final generator = Generator(PaperSize.mm80, profile);
                    final bytes = generator.image(img.decodeImage(pngImage)!);
                    debugPrint('Generated ${bytes.length} ESC/POS bytes');
                  },
                  child: Text(
                    'Generate Bytes',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isPrinting ? null : () => _showPrinterDialog(context),
                  icon: _isPrinting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.print),
                  label: Text(
                    _isPrinting ? 'Printing...' : 'Network Print',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
