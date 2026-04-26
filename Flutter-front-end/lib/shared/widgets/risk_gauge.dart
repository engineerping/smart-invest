// lib/shared/widgets/risk_gauge.dart
import 'package:flutter/material.dart';

class RiskGauge extends StatelessWidget {
  final int productRiskLevel;
  final int userRiskLevel;

  const RiskGauge({
    super.key,
    required this.productRiskLevel,
    required this.userRiskLevel,
  });

  static const _segmentColors = [
    Color(0xFF9CA3AF),
    Color(0xFF1E3A5F),
    Color(0xFF3B82F6),
    Color(0xFFEAB308),
    Color(0xFFF97316),
    Color(0xFFEF4444),
  ];

  @override
  Widget build(BuildContext context) {
    final safe = productRiskLevel <= userRiskLevel;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(6, (i) {
              return Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: _segmentColors[i],
                    borderRadius: i == 0
                        ? const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4))
                        : i == 5
                            ? const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4))
                            : null,
                  ),
                  child: i == productRiskLevel
                      ? Align(
                          alignment: Alignment.bottomCenter,
                          child: Transform.translate(
                            offset: const Offset(0, 16),
                            child: const Text('▼', style: TextStyle(fontSize: 10)),
                          ),
                        )
                      : null,
                ),
              );
            }),
          ),
          if (productRiskLevel == userRiskLevel)
            Align(
              alignment: Alignment.centerRight,
              child: Transform.translate(
                offset: const Offset(0, -16),
                child: const Text('▲', style: TextStyle(fontSize: 10, color: Color(0xFF22C55E))),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Product risk level', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              Text('Your risk tolerance', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            safe
                ? '✓ This fund is within your risk tolerance level.'
                : '⚠ This fund exceeds your risk tolerance level.',
            style: TextStyle(fontSize: 12, color: safe ? const Color(0xFF22C55E) : const Color(0xFFD97706)),
          ),
        ],
      ),
    );
  }
}