import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerPage extends StatefulWidget {
  final String title;
  const ScannerPage({super.key, required this.title});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  MobileScannerController controller = MobileScannerController();
  bool isFlashOn = false;
  bool isFrontCamera = false;
  bool hasScanned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      controller.start();
    }
  }

  void _handleDetection(BarcodeCapture capture) {
    if (hasScanned) return; // Prevent multiple scans

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && mounted && !hasScanned) {
        setState(() => hasScanned = true);
        controller.stop();
        Navigator.of(context).pop(barcode.rawValue);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        controller.dispose();
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: Colors.blue[700],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              controller.dispose();
              Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: () async {
                await controller.toggleTorch();
                setState(() => isFlashOn = !isFlashOn);
              },
            ),
            IconButton(
              icon:
                  Icon(isFrontCamera ? Icons.camera_front : Icons.camera_rear),
              onPressed: () async {
                await controller.switchCamera();
                setState(() => isFrontCamera = !isFrontCamera);
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: _handleDetection,
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.blue[700]!,
                  width: 2,
                ),
              ),
              margin: const EdgeInsets.all(50),
            ),
            if (hasScanned)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
