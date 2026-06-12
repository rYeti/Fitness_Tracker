import 'package:ForgeForm/core/utils/app_logger.dart';
import 'package:ForgeForm/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/data_sources/food_api.dart';
import 'food_detail_view.dart';

// Define isMobileDevice if not provided by platform_detector.dart
// Remove this block if isMobileDevice is already exported from platform_detector.dart
bool get isMobileDevice {
  // You can use defaultTargetPlatform from flutter/foundation.dart
  // This covers Android and iOS as mobile platforms
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

/// This widget is responsible for scanning barcodes using the mobile camera.
class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  bool _isHandlingBarcode = false;

  final MobileScannerController scannerController = MobileScannerController();
  final FoodApi foodApi = FoodApi();

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isHandlingBarcode) return; // Prevent multiple triggers

    // Ensure there's at least one barcode and a non-null rawValue
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _isHandlingBarcode = true;
    final barcode = raw;

    try {
      final barcodeResult = await foodApi.fetchFoodByBarcode(barcode);
      if (!mounted) return;
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => FoodDetailsScreen(
                foodItem: barcodeResult.food,
                category: widget.category,
                isTemplate: widget.isTemplate,
                portionOptions: barcodeResult.portionOptions,
                date: widget.date,
              ),
        ),
      );

      // If we got a result back and are still mounted, return it to the calling screen
      if (result != null && mounted) {
        // This will pass the result back to the calling screen (either food_add_screen or create_meal_template_screen)
        Navigator.pop(context, result);
      }
    } catch (error) {
      AppLogger.e('Error fetching food data: $error');
      if (mounted) {
        final isRateLimit =
            error.toString().contains('429') ||
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
      // Allow scanning again once user returns or on error
      _isHandlingBarcode = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use kIsWeb + conditional shim instead of importing dart:io directly.
    if (kIsWeb || !isMobileDevice) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.scanBarcode)),
        body: Center(
          child: Text(AppLocalizations.of(context)!.barcodeNotSupportedMobile),
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.scanBarcode)),
        body: MobileScanner(
          controller: scannerController,
          onDetect: _onBarcodeDetected,
        ),
      ),
    );
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }
}
