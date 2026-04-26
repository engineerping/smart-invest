// lib/shared/widgets/nav_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/router/app_router.dart';
import '../../features/funds/domain/fund_model.dart';

final navHistoryProvider = FutureProvider.family<List<NavHistoryPoint>, ({String fundId, String period})>((ref, params) async {
  final apiClient = ref.read(apiClientProvider);
  final data = await apiClient.get(
    '/api/funds/${params.fundId}/nav-history',
    queryParams: {'period': params.period},
  );
  if (data is List) {
    return data.map((e) => NavHistoryPoint.fromJson(e as Map<String, dynamic>)).toList();
  }
  return [];
});

class NavChart extends ConsumerStatefulWidget {
  final String fundId;
  final String? chartLabel;

  const NavChart({
    super.key,
    required this.fundId,
    this.chartLabel,
  });

  @override
  ConsumerState<NavChart> createState() => _NavChartState();
}

class _NavChartState extends ConsumerState<NavChart> {
  static const List<String> _periods = ['3M', '6M', '1Y', '3Y', '5Y'];
  String _selectedPeriod = '3M';

  @override
  Widget build(BuildContext context) {
    final navHistoryAsync = ref.watch(navHistoryProvider((fundId: widget.fundId, period: _selectedPeriod)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.chartLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.chartLabel!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        Row(
          children: _periods.map((period) {
            final isSelected = period == _selectedPeriod;
            return GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: const EdgeInsets.only(right: 16, bottom: 4),
                child: Text(
                  period,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? const Color(0xFFE8341A) : const Color(0xFF6B7280),
                    decoration: isSelected ? TextDecoration.underline : null,
                    decorationColor: const Color(0xFFE8341A),
                    decorationThickness: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: navHistoryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (navHistory) {
              if (navHistory.isEmpty) {
                return const Center(child: Text('No data available'));
              }
              return _buildChart(navHistory);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChart(List<NavHistoryPoint> navHistory) {
    if (navHistory.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Calculate percentage return from base NAV
    final baseNav = navHistory.first.nav;
    final chartData = navHistory.asMap().entries.map((entry) {
      final pct = ((entry.value.nav - baseNav) / baseNav) * 100;
      return (date: entry.value.navDate, pct: pct.toStringAsFixed(2));
    }).toList();

    final pctValues = chartData.map((e) => double.parse(e.pct)).toList();
    final minPct = pctValues.reduce((a, b) => a < b ? a : b);
    final maxPct = pctValues.reduce((a, b) => a > b ? a : b);
    final padding = (maxPct - minPct) * 0.1;

    final spots = chartData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), double.parse(entry.value.pct));
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxPct - minPct) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFFE5E7EB),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (chartData.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= chartData.length) {
                  return const SizedBox.shrink();
                }
                // Show MM-DD format
                final dateStr = chartData[index].date;
                final parts = dateStr.split('-');
                final label = parts.length >= 2 ? '${parts[1]}-${parts[2]}' : dateStr;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: (maxPct - minPct) / 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (chartData.length - 1).toDouble(),
        minY: minPct - padding,
        maxY: maxPct + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF3B82F6),
            barWidth: 1.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                return LineTooltipItem(
                  '${chartData[index].date}\n${spot.y.toStringAsFixed(2)}%',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}