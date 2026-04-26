// lib/features/funds/presentation/multi_asset_fund_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/widgets/page_layout.dart';
import '../domain/fund_model.dart';

final multiAssetFundsProvider = FutureProvider<List<Fund>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiEndpoints.multiAssetFunds);
  return (response as List).map((e) => Fund.fromJson(e)).toList();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

const _riskColors = {
  1: Color(0xFF9CA3AF),
  2: Color(0xFF1E3A5F),
  3: Color(0xFF3B82F6),
  4: Color(0xFFEAB308),
  5: Color(0xFFEF4444),
};

const _riskLabels = {
  1: 'Very Low',
  2: 'Low',
  3: 'Medium',
  4: 'High',
  5: 'Very High',
};

class MultiAssetFundListScreen extends ConsumerWidget {
  const MultiAssetFundListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundsAsync = ref.watch(multiAssetFundsProvider);

    return PageLayout(
      title: 'Multi-Asset Funds',
      showBack: true,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF9FAFB),
            child: const Text(
              'Diversify across multiple asset classes with a single fund.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: fundsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              data: (funds) => ListView.separated(
                itemCount: funds.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
                itemBuilder: (context, index) {
                  final fund = funds[index];
                  return InkWell(
                    onTap: () => context.go('/funds/${fund.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fund.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1F2937))),
                                const SizedBox(height: 4),
                                Text(
                                  'Risk Level ${fund.riskLevel} · ${_riskLabels[fund.riskLevel] ?? ''}',
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
                              const Text('NAV', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: _riskColors[fund.riskLevel] ?? const Color(0xFF9CA3AF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}