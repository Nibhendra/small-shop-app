import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklySalesChart extends StatelessWidget {
  final List<Map<String, dynamic>> salesData;

  const WeeklySalesChart({super.key, required this.salesData});

  DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Process Data: Group sales by day for the last 7 days
    final now = DateTime.now();
    List<double> dailyTotals = List.filled(7, 0.0);
    List<String> dayLabels = List.filled(7, '');

    for (int i = 0; i < 7; i++) {
      DateTime date = now.subtract(
        Duration(days: 6 - i),
      ); // 6 days ago to today
      dayLabels[i] = DateFormat('E').format(date); // Mon, Tue...

      // Sum sales for this specific date
      double total = 0;
      for (var sale in salesData) {
        DateTime saleDate = _asDateTime(sale['created_at']);
        if (saleDate.year == date.year &&
            saleDate.month == date.month &&
            saleDate.day == date.day) {
          total += (sale['amount'] as num).toDouble();
        }
      }
      dailyTotals[i] = total;
    }

    double maxVal = dailyTotals.reduce(
      (curr, next) => curr > next ? curr : next,
    );
    if (maxVal == 0) maxVal = 100; // prevent divide by zero in chart

    return SizedBox(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < 7) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              dayLabels[value.toInt()],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      interval: 1,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxVal * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      7,
                      (index) => FlSpot(index.toDouble(), dailyTotals[index]),
                    ),
                    isCurved: true,
                    color: Colors.blueAccent,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
