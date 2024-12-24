import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  final void Function(BarcodeCapture) onDetect;

  const QRScannerScreen({Key? key, required this.onDetect}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanning = true;
  bool _flashOn = false;
  bool _cameraFacingBack = true;

  late AnimationController _animationController;
  late Animation<Offset> _animationSlide;

  @override
  void initState() {
    super.initState();

    // Initialize an animation for the scanning line
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // scanning line travels in 2 seconds
    )..repeat(reverse: true);

    _animationSlide = Tween<Offset>(
      begin: const Offset(0, -0.4),  // line starts above the box
      end: const Offset(0, 0.4),     // line ends below the box
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final Barcode firstBarcode = barcodes.first;
    final String? rawValue = firstBarcode.rawValue;

    if (rawValue != null && rawValue.isNotEmpty) {
      setState(() {
        _isScanning = false;
      });

      widget.onDetect(capture);
      Navigator.of(context).pop();
    }
  }

  void _toggleFlash() {
    setState(() {
      _flashOn = !_flashOn;
      _controller.toggleTorch();
    });
  }

  void _switchCamera() {
    setState(() {
      _cameraFacingBack = !_cameraFacingBack;
      _controller.switchCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scan QR Code"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flash_off : Icons.flash_on,
              color: Colors.cyanAccent,
            ),
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: Icon(
              _cameraFacingBack
                  ? Icons.cameraswitch_outlined
                  : Icons.camera_rear_outlined,
              color: Colors.cyanAccent,
            ),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          // The camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
          ),

          // Custom overlay
          _buildScannerOverlay(),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scanBoxSize = constraints.maxWidth * 0.7;
        final double overlayTop =
            (constraints.maxHeight - scanBoxSize) / 2; // center vertically

        return Stack(
          children: [
            // Dark overlay outside the scanning box
            // Top overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: overlayTop,
              child: Container(color: Colors.black54),
            ),
            // Bottom overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: overlayTop,
              child: Container(color: Colors.black54),
            ),
            // Left overlay
            Positioned(
              top: overlayTop,
              bottom: overlayTop,
              left: 0,
              width: (constraints.maxWidth - scanBoxSize) / 2,
              child: Container(color: Colors.black54),
            ),
            // Right overlay
            Positioned(
              top: overlayTop,
              bottom: overlayTop,
              right: 0,
              width: (constraints.maxWidth - scanBoxSize) / 2,
              child: Container(color: Colors.black54),
            ),

            // The scanning box
            Positioned(
              top: overlayTop,
              left: (constraints.maxWidth - scanBoxSize) / 2,
              child: Container(
                width: scanBoxSize,
                height: scanBoxSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.cyanAccent,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Animated scanning line
                      SlideTransition(
                        position: _animationSlide,
                        child: Container(
                          width: double.infinity,
                          height: 2,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
