// lib/features/funds/presentation/fund_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../domain/fund_model.dart';
import '../../../shared/widgets/nav_chart.dart';
import '../../../shared/widgets/risk_gauge.dart';

final fundDetailProvider = FutureProvider.family<FundDetail, String>((ref, id) async {
  final apiClient = ref.read(apiClientProvider);
  final data = await apiClient.get('/api/funds/$id');
  return FundDetail.fromJson(data as Map<String, dynamic>);
});

final topHoldingsProvider = FutureProvider.family<List<TopHolding>, String>((ref, id) async {
  final apiClient = ref.read(apiClientProvider);
  final data = await apiClient.get('/api/funds/$id/top-holdings');
  if (data is List) {
    return data.map((e) => TopHolding.fromJson(e as Map<String, dynamic>)).toList();
  }
  return [];
});

class FundDetailScreen extends ConsumerStatefulWidget {
  final String fundId;

  const FundDetailScreen({super.key, required this.fundId});

  @override
  ConsumerState<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends ConsumerState<FundDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fundAsync = ref.watch(fundDetailProvider(widget.fundId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => context.go('/funds'),
        ),
        title: fundAsync.maybeWhen(
          data: (fund) => Text(
            fund.name,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          orElse: () => const Text(''),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFE8341A),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFFE8341A),
          indicatorWeight: 2,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Holdings'),
            Tab(text: 'Risk'),
          ],
        ),
      ),
      body: fundAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (fund) => Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(fund: fund, fundId: widget.fundId),
                  _HoldingsTab(fundId: widget.fundId),
                  _RiskTab(fund: fund),
                ],
              ),
            ),
            _InvestNowButton(fundId: widget.fundId),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final FundDetail fund;
  final String fundId;

  const _OverviewTab({required this.fund, required this.fundId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NAV Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current NAV',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fund.currentNav.toStringAsFixed(4),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fund.navDate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          // Nav Chart
          Padding(
            padding: const EdgeInsets.all(16),
            child: NavChart(
              fundId: fundId,
              chartLabel: 'Performance',
            ),
          ),
          // Fund Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Management Fee',
                  value: '${(fund.annualMgmtFee * 100).toStringAsFixed(2)}% p.a.',
                ),
                _InfoRow(
                  label: 'Min Investment',
                  value: 'HKD ${fund.minInvestment.toStringAsFixed(0)}',
                ),
                if (fund.benchmarkIndex != null && fund.benchmarkIndex!.isNotEmpty)
                  _InfoRow(
                    label: 'Benchmark',
                    value: fund.benchmarkIndex!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldingsTab extends ConsumerWidget {
  final String fundId;

  const _HoldingsTab({required this.fundId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdingsAsync = ref.watch(topHoldingsProvider(fundId));

    return holdingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (holdings) {
        if (holdings.isEmpty) {
          return const Center(
            child: Text(
              'No holdings available',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: holdings.length,
          separatorBuilder: (context, index) => const Divider(
            color: Color(0xFFE5E7EB),
            height: 1,
          ),
          itemBuilder: (context, index) {
            final holding = holdings[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      holding.holdingName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Text(
                    '${holding.weight.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RiskTab extends StatelessWidget {
  final FundDetail fund;

  const _RiskTab({required this.fund});

  @override
  Widget build(BuildContext context) {
    return RiskGauge(
      productRiskLevel: fund.riskLevel,
      userRiskLevel: 3,
    );
  }
}

class _InvestNowButton extends StatelessWidget {
  final String fundId;

  const _InvestNowButton({required this.fundId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/order?fundId=$fundId'),
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
              'Invest Now',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
}