class PortionOption {
  final String label;
  final int grams;
  const PortionOption(this.label, this.grams);

  @override
  bool operator ==(Object other) =>
      other is PortionOption && other.grams == grams && other.label == label;

  @override
  int get hashCode => Object.hash(label, grams);

  /// Parses serving size fields from an OpenFoodFacts product map and returns
  /// a list of [PortionOption]s. Returns an empty list when no usable serving
  /// size is found or when the map is from a local source.
  static List<PortionOption> fromProductData(Map<String, dynamic> data) {
    if (data['_source'] == 'local') return const [];

    final rawQty = data['serving_quantity'];
    num? servingQtyNum;
    if (rawQty is num) {
      servingQtyNum = rawQty;
    } else if (rawQty is String) {
      servingQtyNum = num.tryParse(rawQty.trim());
    }

    final servingUnit = data['serving_quantity_unit']?.toString().toLowerCase();
    final servingSize = data['serving_size']?.toString().trim();

    int? servingGrams;
    if (servingUnit == 'g' && servingQtyNum != null && servingQtyNum > 0) {
      servingGrams = servingQtyNum.round();
    } else if (servingUnit == null && servingQtyNum != null && servingQtyNum > 1) {
      servingGrams = servingQtyNum.round();
    }

    if (servingGrams == null && servingSize != null && servingSize.isNotEmpty) {
      for (final pattern in [
        RegExp(r'\((\d+(?:[.,]\d+)?)\s*g\)', caseSensitive: false),
        RegExp(r'(\d+(?:[.,]\d+)?)\s*g\b', caseSensitive: false),
      ]) {
        final match = pattern.firstMatch(servingSize);
        if (match != null) {
          final normalized = match.group(1)!.replaceAll(',', '.');
          final parsed = double.tryParse(normalized)?.round();
          if (parsed != null && parsed > 0) {
            servingGrams = parsed;
            break;
          }
        }
      }
    }

    if (servingGrams == null || servingGrams <= 0) return const [];

    String label;
    if (servingSize != null && servingSize.isNotEmpty) {
      final isOnlyGrams = RegExp(
        r'^\d+(?:[.,]\d+)?\s*g$',
        caseSensitive: false,
      ).hasMatch(servingSize.trim());
      label = isOnlyGrams ? '1 serving' : servingSize;
    } else {
      label = '1 serving';
    }

    return [PortionOption(label, servingGrams)];
  }
}
