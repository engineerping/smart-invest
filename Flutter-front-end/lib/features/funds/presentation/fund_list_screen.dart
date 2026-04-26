// lib/features/funds/presentation/fund_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/fund_model.dart';
import '../../../shared/widgets/page_layout.dart';

final fundsProvider = FutureProvider.family<List<Fund>, String?>((ref, type) async {
  // TODO: Connect to actual API
  return [];
});

const _RISK_COLORS = {
  1: Color(0xFF9CA3AF),
  2: Color(0xFF1E3A5F),
  3: Color(0xFF3B82F6),
  4: Color(0xFFEAB308),
  5: Color(0xFFEF4444),
};

class FundListScreen extends ConsumerWidget {
  final String? type;

  const FundListScreen({super.key, this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundsAsync = ref.watch(fundsProvider(type));

    return PageLayout(
      title: _getTitle(type),
      child: fundsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (funds) {
          if (funds.isEmpty) {
            return const Center(child: Text('No funds available'));
          }
          return ListView.builder(
            itemCount: funds.length,
            itemBuilder: (context, index) {
              final fund = funds[index];
              return _FundListItem(fund: fund);
            },
          );
        },
      ),
    );
  }

  String _getTitle(String? type) {
    switch (type) {
      case 'MONEY_MARKET':
        return 'Money Market';
      case 'BOND_INDEX':
        return 'Bond Index';
      case 'EQUITY_INDEX':
        return 'Equity Index';
      default:
        return 'Funds';
    }
  }
}

class _FundListItem extends StatelessWidget {
  final Fund fund;

  const _FundListItem({required this.fund});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/funds/${fund.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fund.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fund.marketFocus ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fund.currentNav.toStringAsFixed(4),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                const Text(
                  'NAV',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _RISK_COLORS[fund.riskLevel] ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
