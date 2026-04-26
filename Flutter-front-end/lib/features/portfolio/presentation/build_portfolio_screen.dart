// lib/features/portfolio/presentation/build_portfolio_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/widgets/page_layout.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../funds/domain/fund_model.dart';

final equityFundsProvider = FutureProvider<List<Fund>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(
    ApiEndpoints.funds,
    queryParams: {'type': 'EQUITY_INDEX'},
  );
  return (response as List).map((e) => Fund.fromJson(e)).toList();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

const _riskColors = {
  4: Color(0xFFEAB308),
  5: Color(0xFFEF4444),
};

class BuildPortfolioScreen extends ConsumerWidget {
  const BuildPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundsAsync = ref.watch(equityFundsProvider);
    final authState = ref.watch(authNotifierProvider);
    final userRiskLevel = authState.riskLevel ?? 0;
    final canBuild = userRiskLevel == 4 || userRiskLevel == 5;

    return PageLayout(
      title: 'Build Portfolio',
      showBack: true,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF9FAFB),
            child: canBuild
                ? const Text(
                    'Select an equity index fund to build your portfolio with DCA.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  )
                : Column(
                    children: [
                      Text(
                        'Risk level $userRiskLevel cannot build portfolio',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Complete risk assessment to unlock this feature.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
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
                                Text(fund.marketFocus ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                Text('Risk Level ${fund.riskLevel}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
