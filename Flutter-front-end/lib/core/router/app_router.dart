// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_repository.dart';
import '../auth/token_manager.dart';
import '../storage/secure_storage.dart';
import '../api/api_client.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/funds/presentation/fund_list_screen.dart';
import '../../features/funds/presentation/fund_detail_screen.dart';
import '../../features/funds/presentation/multi_asset_fund_list_screen.dart';
import '../../features/portfolio/presentation/build_portfolio_screen.dart';
import '../../features/order/presentation/order_setup_screen.dart';
import '../../features/order/presentation/order_review_screen.dart';
import '../../features/order/presentation/order_terms_screen.dart';
import '../../features/order/presentation/order_success_screen.dart';
import '../../features/holdings/presentation/my_holdings_screen.dart';
import '../../features/holdings/presentation/my_transactions_screen.dart';
import '../../features/plans/presentation/investment_plans_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../shared/widgets/page_layout.dart';

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final secureStorage = SecureStorage();
  final tokenManager = TokenManager(secureStorage);
  final apiClient = ApiClient(tokenManager);
  return AuthRepository(apiClient, tokenManager);
});

// Provider for ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = SecureStorage();
  final tokenManager = TokenManager(secureStorage);
  return ApiClient(tokenManager);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final isLoggedIn = await authRepository.isLoggedIn();
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => PageLayout(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/funds',
            builder: (context, state) => const FundListScreen(),
          ),
          GoRoute(
            path: '/funds/multi-asset',
            builder: (context, state) => const MultiAssetFundListScreen(),
          ),
          GoRoute(
            path: '/funds/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return FundDetailScreen(fundId: id);
            },
          ),
          GoRoute(
            path: '/multi-asset',
            builder: (context, state) => const MultiAssetFundListScreen(),
          ),
          GoRoute(
            path: '/build-portfolio',
            builder: (context, state) => const BuildPortfolioScreen(),
          ),
          GoRoute(
            path: '/portfolio/build',
            builder: (context, state) => const BuildPortfolioScreen(),
          ),
          GoRoute(
            path: '/order/setup',
            builder: (context, state) {
              final fundId = state.uri.queryParameters['fundId'];
              return OrderSetupScreen(fundId: fundId);
            },
          ),
          GoRoute(
            path: '/order/review',
            builder: (context, state) => const OrderReviewScreen(),
          ),
          GoRoute(
            path: '/order/terms',
            builder: (context, state) => const OrderTermsScreen(),
          ),
          GoRoute(
            path: '/order/success',
            builder: (context, state) => const OrderSuccessScreen(),
          ),
          GoRoute(
            path: '/holdings',
            builder: (context, state) => const MyHoldingsScreen(),
          ),
          GoRoute(
            path: '/holdings/transactions',
            builder: (context, state) => const MyTransactionsScreen(),
          ),
          GoRoute(
            path: '/plans',
            builder: (context, state) => const InvestmentPlansScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});
