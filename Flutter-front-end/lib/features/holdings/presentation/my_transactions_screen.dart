// lib/features/holdings/presentation/my_transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../domain/holding_model.dart';

final transactionsOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/api/orders') as Map<String, dynamic>;
  final content = response['content'] as List<dynamic>? ?? [];
  return content.map((json) => Order.fromJson(json as Map<String, dynamic>)).toList();
});

// Brand colors matching React UI
class BrandColors {
  static const Color siDark = Color(0xFF1F2937);
  static const Color siGray = Color(0xFF6B7280);
  static const Color siBorder = Color(0xFFE5E7EB);
}

class MyTransactionsScreen extends ConsumerWidget {
  const MyTransactionsScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.amber;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return BrandColors.siGray;
    }
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return status;
    return status[0] + status.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(transactionsOrdersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Transactions'),
        backgroundColor: Colors.white,
        foregroundColor: BrandColors.siDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/holdings'),
        ),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(
                  fontSize: 14,
                  color: BrandColors.siGray,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: BrandColors.siBorder),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.referenceNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: BrandColors.siDark,
                          ),
                        ),
                        Text(
                          _formatStatus(order.status),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(order.status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.orderDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: BrandColors.siGray,
                          ),
                        ),
                        Text(
                          'HKD ${order.amount.toStringAsFixed(0)}',
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
    );
  }
}
