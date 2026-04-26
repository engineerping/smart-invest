// lib/features/holdings/presentation/my_holdings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../domain/holding_model.dart';

final holdingsProvider = FutureProvider<List<Holding>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/api/holdings/me') as List<dynamic>;
  return response.map((json) => Holding.fromJson(json as Map<String, dynamic>)).toList();
});

final ordersProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.get('/api/orders') as Map<String, dynamic>;
});

// Brand colors matching React UI
class BrandColors {
  static const Color siRed = Color(0xFFE8341A);
  static const Color siDark = Color(0xFF1F2937);
  static const Color siGray = Color(0xFF6B7280);
  static const Color siBorder = Color(0xFFE5E7EB);
  static const Color siLight = Color(0xFFF9FAFB);
}

class MyHoldingsScreen extends ConsumerWidget {
  const MyHoldingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdingsAsync = ref.watch(holdingsProvider);
    final ordersAsync = ref.watch(ordersProvider);

    final pendingCount = ordersAsync.whenOrNull(
      data: (ordersPage) {
        final content = ordersPage['content'] as List<dynamic>? ?? [];
        return content.where((o) => o['status'] == 'PENDING').length;
      },
    ) ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Holdings'),
        backgroundColor: Colors.white,
        foregroundColor: BrandColors.siDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Total market value header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: BrandColors.siLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Market Value',
                  style: TextStyle(
                    fontSize: 12,
                    color: BrandColors.siGray,
                  ),
                ),
                const SizedBox(height: 4),
                holdingsAsync.when(
                  loading: () => const Text('--', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: BrandColors.siDark)),
                  error: (_, __) => const Text('--', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: BrandColors.siDark)),
                  data: (holdings) {
                    final total = holdings.fold<double>(0, (sum, h) => sum + h.marketValue);
                    return Text(
                      total.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: BrandColors.siDark),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/holdings/transactions'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('My Holdings', style: TextStyle(fontSize: 12, color: Color(0xFFE8341A))),
                ),
              ],
            ),
          ),

          // Divider with navigation items
          Column(
            children: [
              // My Transactions row
              InkWell(
                onTap: () => context.go('/holdings/transactions'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: BrandColors.siBorder),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Transactions',
                        style: TextStyle(
                          fontSize: 14,
                          color: BrandColors.siDark,
                        ),
                      ),
                      Row(
                        children: [
                          if (pendingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: BrandColors.siGray,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // My Plans row
              InkWell(
                onTap: () => context.go('/plans'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: BrandColors.siBorder),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Plans',
                        style: TextStyle(
                          fontSize: 14,
                          color: BrandColors.siDark,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: BrandColors.siGray,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Holdings list
          Expanded(
            child: holdingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (holdings) {
                if (holdings.isEmpty) {
                  return const Center(
                    child: Text(
                      'No holdings yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: BrandColors.siGray,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: holdings.length,
                  itemBuilder: (context, index) {
                    final holding = holdings[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: BrandColors.siBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            holding.fundName ?? 'Unknown Fund',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: BrandColors.siDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            holding.fundCode ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: BrandColors.siGray,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Units ${holding.totalUnits}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: BrandColors.siGray,
                                ),
                              ),
                              Text(
                                'Market Value ${holding.marketValue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: BrandColors.siGray,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
