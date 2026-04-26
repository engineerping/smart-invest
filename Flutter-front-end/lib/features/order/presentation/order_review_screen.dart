// lib/features/order/presentation/order_review_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';

class OrderReviewScreen extends ConsumerWidget {
  final Map<String, dynamic>? initState;

  const OrderReviewScreen({super.key, this.initState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 768;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => context.go('/order/setup'),
        ),
        title: const Text(
          'Review Order',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildOrderDetails(context),
            const SizedBox(height: 16),
            _buildDisclaimer(context),
            const SizedBox(height: 24),
            _buildReadTermsButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildOrderDetails(context),
              const SizedBox(height: 16),
              _buildDisclaimer(context),
              const SizedBox(height: 24),
              _buildReadTermsButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetails(BuildContext context) {
    // Get state from GoRouter state.extra
    final state = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final fundId = state?['fundId'] ?? '';
    final orderType = state?['orderType'] ?? 'ONE_TIME';
    final amount = state?['amount'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildDetailRow('Fund', fundId.toString().isNotEmpty ? 'Fund $fundId' : '--'),
          _buildDivider(),
          _buildDetailRow(
            'Order Type',
            orderType == 'ONE_TIME' ? 'One-time' : 'Monthly Plan',
          ),
          _buildDivider(),
          _buildDetailRow(
            'Amount',
            'HKD ${(amount as num).toStringAsFixed(0).replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
                )}',
          ),
          _buildDivider(),
          _buildDetailRow('Settlement', 'T+2'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      color: Color(0xFFE5E7EB),
      height: 1,
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'By proceeding, you agree to the terms and conditions of the investment fund.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildReadTermsButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          final state = GoRouterState.of(context).extra as Map<String, dynamic>?;
          context.go('/order/terms', extra: state);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8341A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Read Terms & Conditions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}