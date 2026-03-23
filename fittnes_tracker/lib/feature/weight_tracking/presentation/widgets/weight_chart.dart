import 'dart:math';
import 'package:ForgeForm/core/app_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeightChart extends StatelessWidget {
  final List<WeightRecordData> weightRecords;

  const WeightChart({Key? key, required this.weightRecords}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Need at least 2 points to draw a chart
    if (weightRecords.length < 2) {
      return Center(
        child: Text(
          'Not enough data to show chart',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    // Sort records by date (oldest to newest)
    final sortedRecords = List<WeightRecordData>.from(weightRecords)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Find min and max weight to set y-axis range
    double minWeight = double.infinity;
    double maxWeight = 0;

    for (final record in sortedRecords) {
      if (record.weight < minWeight) minWeight = record.weight;
      if (record.weight > maxWeight) maxWeight = record.weight;
    }

    // Add some padding to the min/max values for better visualization
    // Ensure there's at least a 1kg difference to avoid division by zero issues
    final yAxisRange = max(1.0, maxWeight - minWeight);
    final padding = yAxisRange * 0.1;
    minWeight = (minWeight - padding).clamp(0, double.infinity);
    maxWeight = maxWeight + padding;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.dividerColor.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1, // This should be safe as it's always 1
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= sortedRecords.length) {
                  return const SizedBox();
                }

                // Show date for every n-th record depending on how many we have
                final interval = max(1, (sortedRecords.length / 5).ceil());
                if (value.toInt() % interval != 0 &&
                    value.toInt() != sortedRecords.length - 1) {
                  return const SizedBox();
                }

                final date = sortedRecords[value.toInt()].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('MMM d').format(date),
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: max(
                0.1,
                (maxWeight - minWeight) / 4,
              ), // Ensure interval is never zero
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    value.toStringAsFixed(1),
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 1),
            left: BorderSide(color: theme.dividerColor, width: 1),
            right: BorderSide(color: Colors.transparent),
            top: BorderSide(color: Colors.transparent),
          ),
        ),
        minX: 0,
        maxX: sortedRecords.length - 1.0,
        minY: minWeight,
        maxY: maxWeight,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final record = sortedRecords[touchedSpot.x.toInt()];
                return LineTooltipItem(
                  '${record.weight.toStringAsFixed(1)} kg\n${DateFormat('MMM d, y').format(record.date)}',
                  TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(sortedRecords.length, (index) {
              return FlSpot(index.toDouble(), sortedRecords[index].weight);
            }),
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: theme.colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: theme.colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
