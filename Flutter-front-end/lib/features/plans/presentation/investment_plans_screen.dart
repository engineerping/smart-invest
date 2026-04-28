// lib/features/plans/presentation/investment_plans_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/widgets/page_layout.dart';
import '../domain/plan_model.dart';

final plansProvider = FutureProvider<List<Plan>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiEndpoints.plans);
  return (response as List).map((e) => Plan.fromJson(e)).toList();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

const _statusStyles = {
  'ACTIVE': {'bg': Color(0xFF22C55E), 'text': Color(0xFF15803D)},
  'TERMINATED': {'bg': Color(0xFF9CA3AF), 'text': Color(0xFF6B7280)},
};

class InvestmentPlansScreen extends ConsumerWidget {
  const InvestmentPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);
    t(key, {args}) => key; // i18n placeholder

    return PageLayout(
      title: 'Investment Plans',
      showBack: true,
      child: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('No investment plans yet', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280))),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Explore Funds', style: TextStyle(color: Color(0xFFE8341A))),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: plans.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
            itemBuilder: (context, index) {
              final plan = plans[index];
              final statusStyle = _statusStyles[plan.status] ?? {'bg': const Color(0xFFE5E7EB), 'text': const Color(0xFF6B7280)};
              return InkWell(
                onTap: () => context.go('/plans/${plan.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan.referenceNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1F2937))),
                            const SizedBox(height: 2),
                            Text(plan.fundName ?? 'Fund', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            const SizedBox(height: 2),
                            Text('Monthly ${plan.monthlyAmount?.toStringAsFixed(0) ?? '--'}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            Text('Next contribution ${plan.nextContributionDate}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusStyle['bg']?.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(plan.status, style: TextStyle(fontSize: 12, color: statusStyle['text'])),
                          ),
                          const SizedBox(height: 4),
                          Text('Invested ${plan.totalInvested?.toStringAsFixed(0) ?? '--'}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          Text('${plan.completedOrders} orders', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}