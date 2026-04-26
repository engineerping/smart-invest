// lib/features/home/presentation/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../auth/presentation/login_screen.dart';

// Provider for portfolio summary
final portfolioSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/api/holdings/me/summary');
  return response as Map<String, dynamic>;
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isEnglish = true;

  void _toggleLanguage() {
    setState(() {
      _isEnglish = !_isEnglish;
    });
  }

  Future<void> _handleLogout() async {
    await ref.read(authNotifierProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: BrandColors.siBorder),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo and brand name
                  Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CustomPaint(painter: LogoPainter()),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Smart Invest',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: BrandColors.siDark,
                        ),
                      ),
                    ],
                  ),
                  // Language toggle and logout
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLanguage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [BrandColors.siRed, BrandColors.siOrange],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: BrandColors.siRed.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _isEnglish ? '中文' : 'EN',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _handleLogout,
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 12,
                            color: BrandColors.siGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total market value card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: BrandColors.siLight,
                        border: Border(
                          bottom: BorderSide(color: BrandColors.siBorder),
                        ),
                      ),
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
                          summaryAsync.when(
                            data: (data) {
                              final totalMarketValue = data['totalMarketValue'] as num?;
                              return Text(
                                totalMarketValue?.toStringAsFixed(2) ?? '—',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: BrandColors.siDark,
                                ),
                              );
                            },
                            loading: () => const Text(
                              '—',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: BrandColors.siDark,
                              ),
                            ),
                            error: (_, __) => const Text(
                              '—',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: BrandColors.siDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => context.push('/holdings'),
                            child: const Text(
                              'My Holdings >',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: BrandColors.siRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Fund categories section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invest Funds',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: BrandColors.siDark,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Money Market
                          _FundCategoryButton(
                            title: 'Money Market',
                            description: 'Low risk, high liquidity fund',
                            onTap: () => context.push('/funds?type=MONEY_MARKET'),
                          ),
                          const SizedBox(height: 8),

                          // Bond Index
                          _FundCategoryButton(
                            title: 'Bond Index',
                            description: 'Medium risk, fixed income fund',
                            onTap: () => context.push('/funds?type=BOND_INDEX'),
                          ),
                          const SizedBox(height: 8),

                          // Equity Index
                          _FundCategoryButton(
                            title: 'Equity Index',
                            description: 'Higher risk, equity growth fund',
                            onTap: () => context.push('/funds?type=EQUITY_INDEX'),
                          ),
                        ],
                      ),
                    ),

                    // Portfolios section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invest Portfolios',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: BrandColors.siDark,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Multi-Asset Fund
                          _FundCategoryButton(
                            title: 'Multi-Asset Fund',
                            description: 'Diversified portfolio across assets',
                            onTap: () => context.push('/multi-asset'),
                          ),
                          const SizedBox(height: 8),

                          // Build Portfolio
                          _FundCategoryButton(
                            title: 'Build Portfolio',
                            description: 'Create your own customized portfolio',
                            onTap: () => context.push('/build-portfolio'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FundCategoryButton extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;

  const _FundCategoryButton({
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.siBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: BrandColors.siDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: BrandColors.siGray,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              '›',
              style: TextStyle(
                fontSize: 18,
                color: BrandColors.siGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
