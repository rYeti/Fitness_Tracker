import 'package:ForgeForm/core/forge_motion.dart';
import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/data_sources/food_api.dart';
import 'food_detail_view.dart';

bool get isMobileDevice {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({
    super.key,
    required this.category,
    this.isTemplate = false,
    this.date,
  });

  final String category;
  final bool isTemplate;
  final DateTime? date;

  @override
  _BarcodeScannerViewState createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView>
    with SingleTickerProviderStateMixin {
  bool _isHandlingBarcode = false;
  bool _torchOn = false;
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  final MobileScannerController scannerController = MobileScannerController();
  final FoodApi foodApi = FoodApi();

  @override
  void initState() {
    super.initState();
    // Started in didChangeDependencies rather than here: whether it should
    // run at all depends on the reduce-motion setting, and MediaQuery is not
    // available during initState.
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A purely decorative loop is the case a duration cannot express: there
    // is no "instant" version of an animation that never ends, so the only
    // way to respect the setting is to stop driving it. This one runs in
    // front of someone trying to hold a camera steady over a barcode, which
    // is close to the canonical reason the OS setting exists.
    if (ForgeMotion.isReduced(context)) {
      _scanLineController
        ..stop()
        ..value = 0.5; // parked mid-frame, so the guide line stays visible
    } else if (!_scanLineController.isAnimating) {
      _scanLineController.repeat(reverse: true);
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isHandlingBarcode) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _isHandlingBarcode = true;

    try {
      final barcodeResult = await foodApi.fetchFoodByBarcode(raw);
      if (!mounted) return;
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FoodDetailsScreen(
            foodItem: barcodeResult.food,
            category: widget.category,
            isTemplate: widget.isTemplate,
            portionOptions: barcodeResult.portionOptions,
            date: widget.date,
          ),
        ),
      );
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    } catch (error) {
      AppLogger.e('Error fetching food data: $error');
      if (mounted) {
        final isRateLimit = error.toString().contains('429') ||
            error.toString().contains('rate');
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRateLimit
                  ? l10n.tooManyRequests
                  : l10n.couldNotFetchProductData,
            ),
          ),
        );
      }
    } finally {
      _isHandlingBarcode = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !isMobileDevice) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.scanBarcode)),
        body: Center(
          child: Text(AppLocalizations.of(context)!.barcodeNotSupportedMobile),
        ),
      );
    }

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(AppLocalizations.of(context)!.scanBarcode),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
              color: Colors.white,
            ),
            onPressed: () {
              scannerController.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: _onBarcodeDetected,
          ),
          AnimatedBuilder(
            animation: _scanLineAnimation,
            builder: (context, _) => CustomPaint(
              painter: _ScannerOverlayPainter(
                scanLineProgress: _scanLineAnimation.value,
                primaryColor: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    scannerController.dispose();
    super.dispose();
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanLineProgress;
  final Color primaryColor;

  _ScannerOverlayPainter({
    required this.scanLineProgress,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLength = 28.0;
    const cornerStroke = 3.0;

    final scanAreaWidth = size.width * 0.75;
    final scanAreaHeight = scanAreaWidth * 0.38;
    final left = (size.width - scanAreaWidth) / 2;
    final top = (size.height - scanAreaHeight) / 2;
    final right = left + scanAreaWidth;
    final bottom = top + scanAreaHeight;
    final scanRect = Rect.fromLTRB(left, top, right, bottom);

    // Semi-dark overlay with transparent cutout
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRect(scanRect)
        ..fillType = PathFillType.evenOdd,
      overlayPaint,
    );

    // Corner brackets
    final cornerPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = cornerStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // Top-left
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(right - cornerLength, top), Offset(right, top), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(left, bottom - cornerLength), Offset(left, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(right - cornerLength, bottom), Offset(right, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom - cornerLength), Offset(right, bottom), cornerPaint);

    // Animated scan line
    final scanLineY = top + scanAreaHeight * scanLineProgress;
    canvas.drawLine(
      Offset(left + cornerStroke, scanLineY),
      Offset(right - cornerStroke, scanLineY),
      Paint()
        ..color = primaryColor
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter old) =>
      old.scanLineProgress != scanLineProgress;
}
