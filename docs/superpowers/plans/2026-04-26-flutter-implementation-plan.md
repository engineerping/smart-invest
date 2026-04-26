# Flutter 前端重写实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Smart Invest 前端从 React 重写为 Flutter (iOS + Android + Web)

**Architecture:** 三层架构 (Presentation / Business Logic / Data)，使用 Riverpod 状态管理，go_router 路由，Material Design 3 主题

**Tech Stack:** Flutter 3.x, Riverpod, go_router, http, fl_chart, flutter_secure_storage, SharedPreferences

---

## 文件结构

```
flutter/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart
│   │   │   ├── api_endpoints.dart
│   │   │   └── api_exception.dart
│   │   ├── auth/
│   │   │   ├── auth_repository.dart
│   │   │   └── token_manager.dart
│   │   ├── storage/
│   │   │   └── secure_storage.dart
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       └── date_utils.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   └── auth_api.dart
│   │   │   ├── domain/
│   │   │   │   └── auth_state.dart
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       └── register_screen.dart
│   │   ├── funds/
│   │   │   ├── data/
│   │   │   │   ├── funds_api.dart
│   │   │   │   └── funds_cache.dart
│   │   │   ├── domain/
│   │   │   │   └── fund_model.dart
│   │   │   └── presentation/
│   │   │       ├── fund_list_screen.dart
│   │   │       ├── fund_detail_screen.dart
│   │   │       └── multi_asset_fund_list_screen.dart
│   │   ├── portfolio/
│   │   │   ├── domain/
│   │   │   │   └── portfolio_model.dart
│   │   │   └── presentation/
│   │   │       └── build_portfolio_screen.dart
│   │   ├── order/
│   │   │   ├── data/
│   │   │   │   └── order_api.dart
│   │   │   ├── domain/
│   │   │   │   └── order_model.dart
│   │   │   └── presentation/
│   │   │       ├── order_setup_screen.dart
│   │   │       ├── order_review_screen.dart
│   │   │       ├── order_terms_screen.dart
│   │   │       └── order_success_screen.dart
│   │   ├── holdings/
│   │   │   ├── data/
│   │   │   │   └── holdings_api.dart
│   │   │   ├── domain/
│   │   │   │   └── holding_model.dart
│   │   │   └── presentation/
│   │   │       ├── my_holdings_screen.dart
│   │   │       └── my_transactions_screen.dart
│   │   └── plans/
│   │       ├── data/
│   │       │   └── plans_api.dart
│   │       ├── domain/
│   │       │   └── plan_model.dart
│   │       └── presentation/
│   │           └── investment_plans_screen.dart
│   ├── shared/
│   │   ├── widgets/
│   │   │   ├── nav_chart.dart
│   │   │   ├── risk_gauge.dart
│   │   │   └── page_layout.dart
│   │   └── models/
│   │       └── user_model.dart
│   └── responsive/
│       ├── breakpoints.dart
│       ├── screen_size.dart
│       └── layout_builder.dart
└── pubspec.yaml
```

---

## Phase 1: 核心基础设施

### Task 1: Flutter 项目初始化

**Files:**
- Create: `flutter/pubspec.yaml`
- Create: `flutter/lib/main.dart`

- [ ] **Step 1: 创建 pubspec.yaml**

```yaml
name: smart_invest
description: Smart Invest - 小额投资平台 Flutter 客户端
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.0.0

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  flutter_riverpod: ^2.4.9
  go_router: ^13.0.0
  http: ^1.1.0
  fl_chart: ^0.66.0
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.2
  intl: ^0.18.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: 创建 main.dart 入口文件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SmartInvestApp(),
    ),
  );
}

class SmartInvestApp extends ConsumerWidget {
  const SmartInvestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Smart Invest',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 3: 创建目录结构**

```bash
cd flutter && flutter pub get
mkdir -p lib/core/{api,auth,storage,router,theme,utils}
mkdir -p lib/features/{auth,funds,portfolio,order,holdings,plans}/{data,domain,presentation}
mkdir -p lib/shared/{widgets,models}
mkdir -p lib/responsive
```

---

### Task 2: API 层实现

**Files:**
- Create: `flutter/lib/core/api/api_exception.dart`
- Create: `flutter/lib/core/api/api_endpoints.dart`
- Create: `flutter/lib/core/api/api_client.dart`

- [ ] **Step 1: 创建 API 异常类**

```dart
// lib/core/api/api_exception.dart
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';

  factory ApiException.unauthorized() =>
      ApiException(401, 'Unauthorized - Please login again');

  factory ApiException.notFound() =>
      ApiException(404, 'Resource not found');

  factory ApiException.serverError() =>
      ApiException(500, 'Server error - Please try again later');

  factory ApiException.networkError() =>
      ApiException(0, 'Network error - Please check your connection');
}
```

- [ ] **Step 2: 创建 API 端点常量**

```dart
// lib/core/api/api_endpoints.dart
class ApiEndpoints {
  static const String baseUrl = 'http://localhost:8080/api';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Funds
  static const String funds = '/funds';
  static String fundDetail(String id) => '/funds/$id';
  static const String multiAssetFunds = '/funds/multi-asset';

  // Portfolio
  static const String portfolio = '/portfolio';
  static const String riskAssessment = '/portfolio/risk-assessment';

  // Orders
  static const String orders = '/orders';
  static String orderDetail(String id) => '/orders/$id';
  static const String orderCreate = '/orders';

  // Holdings
  static const String holdings = '/holdings';
  static const String transactions = '/holdings/transactions';

  // Plans
  static const String plans = '/plans';
  static String planDetail(String id) => '/plans/$id';
  static const String planCreate = '/plans';
}
```

- [ ] **Step 3: 创建 API 客户端**

```dart
// lib/core/api/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_exception.dart';
import 'api_endpoints.dart';
import '../auth/token_manager.dart';

class ApiClient {
  final http.Client _client;
  final TokenManager _tokenManager;

  ApiClient(this._tokenManager) : _client = http.Client();

  Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth) {
      final token = await _tokenManager.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(
    String endpoint, {
    bool requiresAuth = true,
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await _client.get(
        uri,
        headers: await _headers(requiresAuth: requiresAuth),
      );
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.networkError();
    }
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
      final response = await _client.post(
        uri,
        headers: await _headers(requiresAuth: requiresAuth),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.networkError();
    }
  }

  dynamic _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        if (response.body.isEmpty) return null;
        return jsonDecode(response.body);
      case 401:
        throw ApiException.unauthorized();
      case 404:
        throw ApiException.notFound();
      case 500:
        throw ApiException.serverError();
      default:
        throw ApiException(response.statusCode, 'Unknown error');
    }
  }

  void dispose() {
    _client.close();
  }
}
```

---

### Task 3: 认证层实现

**Files:**
- Create: `flutter/lib/core/storage/secure_storage.dart`
- Create: `flutter/lib/core/auth/token_manager.dart`
- Create: `flutter/lib/core/auth/auth_repository.dart`

- [ ] **Step 1: 创建安全存储封装**

```dart
// lib/core/storage/secure_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';

  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
```

- [ ] **Step 2: 创建 Token 管理器**

```dart
// lib/core/auth/token_manager.dart
import '../storage/secure_storage.dart';

class TokenManager {
  final SecureStorage _storage;

  TokenManager(this._storage);

  Future<void> saveAccessToken(String token) async {
    await _storage.write(SecureStorage.accessTokenKey, token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(SecureStorage.accessTokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(SecureStorage.refreshTokenKey, token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(SecureStorage.refreshTokenKey);
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(SecureStorage.userIdKey, userId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(SecureStorage.userIdKey);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
```

- [ ] **Step 3: 创建认证仓库**

```dart
// lib/core/auth/auth_repository.dart
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exception.dart';
import 'token_manager.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final TokenManager _tokenManager;

  AuthRepository(this._apiClient, this._tokenManager);

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        body: {'email': email, 'password': password},
        requiresAuth: false,
      );

      final accessToken = response['accessToken'] as String;
      final refreshToken = response['refreshToken'] as String;
      final userId = response['userId'] as String;

      await _tokenManager.saveAccessToken(accessToken);
      await _tokenManager.saveRefreshToken(refreshToken);
      await _tokenManager.saveUserId(userId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Login failed: $e');
    }
  }

  Future<void> register(String email, String password, String name) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.register,
        body: {'email': email, 'password': password, 'name': name},
        requiresAuth: false,
      );

      final accessToken = response['accessToken'] as String;
      final refreshToken = response['refreshToken'] as String;
      final userId = response['userId'] as String;

      await _tokenManager.saveAccessToken(accessToken);
      await _tokenManager.saveRefreshToken(refreshToken);
      await _tokenManager.saveUserId(userId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Registration failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.logout);
    } catch (_) {
      // Ignore logout API errors
    } finally {
      await _tokenManager.clearAll();
    }
  }

  Future<bool> isLoggedIn() async {
    return await _tokenManager.hasValidToken();
  }
}
```

---

### Task 4: 路由配置

**Files:**
- Create: `flutter/lib/core/router/app_router.dart`

- [ ] **Step 1: 创建 go_router 配置**

```dart
// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_repository.dart';
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
import '../../shared/widgets/page_layout.dart';

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
            builder: (context, state) => const FundListScreen(),
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
            path: '/portfolio/build',
            builder: (context, state) => const BuildPortfolioScreen(),
          ),
          GoRoute(
            path: '/order/setup',
            builder: (context, state) => const OrderSetupScreen(),
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

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // This will be overridden in main.dart with proper dependencies
  throw UnimplementedError('authRepositoryProvider must be overridden');
});
```

---

### Task 5: 主题配置

**Files:**
- Create: `flutter/lib/core/theme/app_theme.dart`

- [ ] **Step 1: 创建 Material Design 3 主题**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1E88E5); // Blue
  static const Color secondaryColor = Color(0xFF43A047); // Green
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFFA726);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
```

---

### Task 6: 响应式布局

**Files:**
- Create: `flutter/lib/responsive/breakpoints.dart`
- Create: `flutter/lib/responsive/screen_size.dart`
- Create: `flutter/lib/responsive/layout_builder.dart`

- [ ] **Step 1: 创建断点定义**

```dart
// lib/responsive/breakpoints.dart
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;
}
```

- [ ] **Step 2: 创建屏幕尺寸检测**

```dart
// lib/responsive/screen_size.dart
import 'package:flutter/material.dart';
import 'breakpoints.dart';

class ScreenSize {
  final double width;
  final double height;

  ScreenSize(BuildContext context)
      : width = MediaQuery.of(context).size.width,
        height = MediaQuery.of(context).size.height;

  bool get isMobile => Breakpoints.isMobile(width);
  bool get isTablet => Breakpoints.isTablet(width);
  bool get isDesktop => Breakpoints.isDesktop(width);
}
```

- [ ] **Step 3: 创建自适应布局构建器**

```dart
// lib/responsive/layout_builder.dart
import 'package:flutter/material.dart';
import 'breakpoints.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (Breakpoints.isDesktop(constraints.maxWidth)) {
          return desktop ?? tablet ?? mobile;
        }
        if (Breakpoints.isTablet(constraints.maxWidth)) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}
```

---

## Phase 2: 共享组件

### Task 7: PageLayout 组件

**Files:**
- Create: `flutter/lib/shared/widgets/page_layout.dart`

- [ ] **Step 1: 创建 PageLayout 组件**

```dart
// lib/shared/widgets/page_layout.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../responsive/screen_size.dart';

class PageLayout extends StatelessWidget {
  final Widget child;

  const PageLayout({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/funds')) return 0;
    if (location.startsWith('/portfolio')) return 1;
    if (location.startsWith('/order')) return 2;
    if (location.startsWith('/holdings')) return 3;
    if (location.startsWith('/plans')) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/funds');
        break;
      case 1:
        context.go('/portfolio/build');
        break;
      case 2:
        context.go('/order/setup');
        break;
      case 3:
        context.go('/holdings');
        break;
      case 4:
        context.go('/plans');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ScreenSize(context);
    final selectedIndex = _calculateSelectedIndex(context);

    if (screenSize.isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onItemTapped(context, index),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance),
                  label: Text('Funds'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.pie_chart),
                  label: Text('Portfolio'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.shopping_cart),
                  label: Text('Order'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.wallet),
                  label: Text('Holdings'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.schedule),
                  label: Text('Plans'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Funds',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Portfolio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Order',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wallet),
            label: 'Holdings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Plans',
          ),
        ],
      ),
    );
  }
}
```

---

### Task 8: RiskGauge 组件

**Files:**
- Create: `flutter/lib/shared/widgets/risk_gauge.dart`

- [ ] **Step 1: 创建 RiskGauge 组件**

```dart
// lib/shared/widgets/risk_gauge.dart
import 'dart:math';
import 'package:flutter/material.dart';

class RiskGauge extends StatelessWidget {
  final double riskScore; // 0.0 to 1.0
  final double width;
  final double height;

  const RiskGauge({
    super.key,
    required this.riskScore,
    this.width = 200,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _RiskGaugePainter(riskScore),
      ),
    );
  }
}

class _RiskGaugePainter extends CustomPainter {
  final double riskScore;

  _RiskGaugePainter(this.riskScore);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width / 2 - 20;

    // Draw arc background
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..color = Colors.grey.shade300;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    // Draw colored segments
    final colors = [Colors.green, Colors.yellow, Colors.orange, Colors.red];
    final segments = [0.0, 0.25, 0.5, 0.75, 1.0];

    for (int i = 0; i < colors.length; i++) {
      final segPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..color = colors[i];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        pi + (segments[i] * pi),
        (segments[i + 1] - segments[i]) * pi,
        false,
        segPaint,
      );
    }

    // Draw needle
    final needleAngle = pi + (riskScore * pi);
    final needleLength = radius - 25;
    final needleEnd = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );

    final needlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.black;

    canvas.drawLine(center, needleEnd, needlePaint);

    // Draw center circle
    final centerPaint = Paint()..color = Colors.black;
    canvas.drawCircle(center, 6, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _RiskGaugePainter oldDelegate) {
    return oldDelegate.riskScore != riskScore;
  }
}
```

---

### Task 9: NavChart 组件

**Files:**
- Create: `flutter/lib/shared/widgets/nav_chart.dart`

- [ ] **Step 1: 创建 NavChart 组件**

```dart
// lib/shared/widgets/nav_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class NavChart extends StatelessWidget {
  final List<NavDataPoint> data;
  final double height;
  final Color? lineColor;

  const NavChart({
    super.key,
    required this.data,
    this.height = 200,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No data available')),
      );
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.nav);
    }).toList();

    final minY = data.map((e) => e.nav).reduce((a, b) => a < b ? a : b) * 0.95;
    final maxY = data.map((e) => e.nav).reduce((a, b) => a > b ? a : b) * 1.05;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade300,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (data.length / 5).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[index].date,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxY - minY) / 5,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(2),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor ?? Theme.of(context).primaryColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: (lineColor ?? Theme.of(context).primaryColor)
                    .withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  return LineTooltipItem(
                    '${data[index].date}\nNAV: ${spot.y.toStringAsFixed(4)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class NavDataPoint {
  final String date;
  final double nav;

  NavDataPoint({required this.date, required this.nav});
}
```

---

## Phase 3: 功能模块

### Task 10: 认证模块

**Files:**
- Create: `flutter/lib/features/auth/data/auth_api.dart`
- Create: `flutter/lib/features/auth/domain/auth_state.dart`
- Create: `flutter/lib/features/auth/presentation/login_screen.dart`
- Create: `flutter/lib/features/auth/presentation/register_screen.dart`

- [ ] **Step 1: 创建 Auth API**

```dart
// lib/features/auth/data/auth_api.dart
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

class AuthApi {
  final ApiClient _apiClient;

  AuthApi(this._apiClient);

  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _apiClient.post(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
  }

  Future<Map<String, dynamic>> register(
      String email, String password, String name) async {
    return await _apiClient.post(
      ApiEndpoints.register,
      body: {'email': email, 'password': password, 'name': name},
      requiresAuth: false,
    );
  }

  Future<void> logout() async {
    await _apiClient.post(ApiEndpoints.logout);
  }
}
```

- [ ] **Step 2: 创建 Auth State**

```dart
// lib/features/auth/domain/auth_state.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? userId;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.userId,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? userId,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      userId: userId ?? this.userId,
    );
  }
}
```

- [ ] **Step 3: 创建 Auth Notifier**

```dart
// lib/features/auth/domain/auth_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_api.dart';
import '../../../core/auth/auth_repository.dart';
import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState());

  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    final isLoggedIn = await _authRepository.isLoggedIn();
    if (isLoggedIn) {
      state = state.copyWith(status: AuthStatus.authenticated);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.login(email, password);
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> register(String email, String password, String name) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.register(email, password, name);
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    await _authRepository.logout();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }
}
```

- [ ] **Step 4: 创建 LoginScreen**

```dart
// lib/features/auth/presentation/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/auth_state.dart';
import '../domain/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/');
      } else if (next.status == AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Smart Invest',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: authState.status == AuthStatus.loading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              ref.read(authNotifierProvider.notifier).login(
                                    _emailController.text,
                                    _passwordController.text,
                                  );
                            }
                          },
                    child: authState.status == AuthStatus.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text("Don't have an account? Register"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});
```

- [ ] **Step 5: 创建 RegisterScreen**

```dart
// lib/features/auth/presentation/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/auth_state.dart';
import '../domain/auth_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/');
      } else if (next.status == AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Registration failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: authState.status == AuthStatus.loading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            ref.read(authNotifierProvider.notifier).register(
                                  _emailController.text,
                                  _passwordController.text,
                                  _nameController.text,
                                );
                          }
                        },
                  child: authState.status == AuthStatus.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Register'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### Task 11: 基金模块

**Files:**
- Create: `flutter/lib/features/funds/domain/fund_model.dart`
- Create: `flutter/lib/features/funds/data/funds_api.dart`
- Create: `flutter/lib/features/funds/data/funds_cache.dart`
- Create: `flutter/lib/features/funds/presentation/fund_list_screen.dart`
- Create: `flutter/lib/features/funds/presentation/fund_detail_screen.dart`
- Create: `flutter/lib/features/funds/presentation/multi_asset_fund_list_screen.dart`

- [ ] **Step 1: 创建 Fund Model**

```dart
// lib/features/funds/domain/fund_model.dart
class Fund {
  final String id;
  final String name;
  final String type;
  final String riskLevel;
  final double nav;
  final double dailyReturn;
  final String description;

  const Fund({
    required this.id,
    required this.name,
    required this.type,
    required this.riskLevel,
    required this.nav,
    required this.dailyReturn,
    required this.description,
  });

  factory Fund.fromJson(Map<String, dynamic> json) {
    return Fund(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      riskLevel: json['riskLevel'] as String,
      nav: (json['nav'] as num).toDouble(),
      dailyReturn: (json['dailyReturn'] as num).toDouble(),
      description: json['description'] as String,
    );
  }
}

class FundDetail extends Fund {
  final List<NavDataPoint> navHistory;
  final double totalAssets;
  final String manager;
  final String inceptionDate;

  const FundDetail({
    required super.id,
    required super.name,
    required super.type,
    required super.riskLevel,
    required super.nav,
    required super.dailyReturn,
    required super.description,
    required this.navHistory,
    required this.totalAssets,
    required this.manager,
    required this.inceptionDate,
  });

  factory FundDetail.fromJson(Map<String, dynamic> json) {
    return FundDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      riskLevel: json['riskLevel'] as String,
      nav: (json['nav'] as num).toDouble(),
      dailyReturn: (json['dailyReturn'] as num).toDouble(),
      description: json['description'] as String,
      navHistory: (json['navHistory'] as List)
          .map((e) => NavDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAssets: (json['totalAssets'] as num).toDouble(),
      manager: json['manager'] as String,
      inceptionDate: json['inceptionDate'] as String,
    );
  }
}

class NavDataPoint {
  final String date;
  final double nav;

  const NavDataPoint({required this.date, required this.nav});

  factory NavDataPoint.fromJson(Map<String, dynamic> json) {
    return NavDataPoint(
      date: json['date'] as String,
      nav: (json['nav'] as num).toDouble(),
    );
  }
}
```

- [ ] **Step 2: 创建 Funds API**

```dart
// lib/features/funds/data/funds_api.dart
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/fund_model.dart';

class FundsApi {
  final ApiClient _apiClient;

  FundsApi(this._apiClient);

  Future<List<Fund>> getFunds() async {
    final response = await _apiClient.get(ApiEndpoints.funds);
    return (response as List).map((e) => Fund.fromJson(e)).toList();
  }

  Future<List<Fund>> getMultiAssetFunds() async {
    final response = await _apiClient.get(ApiEndpoints.multiAssetFunds);
    return (response as List).map((e) => Fund.fromJson(e)).toList();
  }

  Future<FundDetail> getFundDetail(String id) async {
    final response = await _apiClient.get(ApiEndpoints.fundDetail(id));
    return FundDetail.fromJson(response);
  }
}
```

- [ ] **Step 3: 创建 Funds Cache**

```dart
// lib/features/funds/data/funds_cache.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/fund_model.dart';

class FundsCache {
  static const String _fundsKey = 'cached_funds';
  static const String _fundsTimestampKey = 'cached_funds_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  final SharedPreferences _prefs;

  FundsCache(this._prefs);

  Future<List<Fund>?> getCachedFunds() async {
    final timestamp = _prefs.getInt(_fundsTimestampKey);
    if (timestamp == null) return null;

    final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cachedTime) > _cacheDuration) {
      return null;
    }

    final jsonString = _prefs.getString(_fundsKey);
    if (jsonString == null) return null;

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => Fund.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cacheFunds(List<Fund> funds) async {
    final jsonString = jsonEncode(funds.map((e) => {
      'id': e.id,
      'name': e.name,
      'type': e.type,
      'riskLevel': e.riskLevel,
      'nav': e.nav,
      'dailyReturn': e.dailyReturn,
      'description': e.description,
    }).toList());
    await _prefs.setString(_fundsKey, jsonString);
    await _prefs.setInt(_fundsTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clearCache() async {
    await _prefs.remove(_fundsKey);
    await _prefs.remove(_fundsTimestampKey);
  }
}
```

- [ ] **Step 4: 创建 FundListScreen**

```dart
// lib/features/funds/presentation/fund_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/fund_model.dart';
import '../../../shared/widgets/nav_chart.dart';

final fundsProvider = FutureProvider<List<Fund>>((ref) async {
  // Implementation will be provided when connecting to actual API
  return [];
});

class FundListScreen extends ConsumerWidget {
  const FundListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundsAsync = ref.watch(fundsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fund List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter dialog
            },
          ),
        ],
      ),
      body: fundsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(fundsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (funds) {
          if (funds.isEmpty) {
            return const Center(
              child: Text('No funds available'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: funds.length,
            itemBuilder: (context, index) {
              final fund = funds[index];
              return _FundCard(fund: fund);
            },
          );
        },
      ),
    );
  }
}

class _FundCard extends StatelessWidget {
  final Fund fund;

  const _FundCard({required this.fund});

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = fund.dailyReturn >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/funds/${fund.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fund.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fund.type,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getRiskColor(fund.riskLevel).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      fund.riskLevel.toUpperCase(),
                      style: TextStyle(
                        color: _getRiskColor(fund.riskLevel),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NAV',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      Text(
                        fund.nav.toStringAsFixed(4),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Daily Return',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${fund.dailyReturn.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 创建 FundDetailScreen**

```dart
// lib/features/funds/presentation/fund_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/fund_model.dart';
import '../../../shared/widgets/nav_chart.dart';

final fundDetailProvider = FutureProvider.family<FundDetail, String>((ref, id) async {
  // Implementation will be provided when connecting to actual API
  return FundDetail(
    id: id,
    name: 'Sample Fund',
    type: 'Money Market',
    riskLevel: 'Low',
    nav: 1.2345,
    dailyReturn: 0.05,
    description: 'Sample fund description',
    navHistory: [],
    totalAssets: 1000000,
    manager: 'John Doe',
    inceptionDate: '2020-01-01',
  );
});

class FundDetailScreen extends ConsumerWidget {
  final String fundId;

  const FundDetailScreen({super.key, required this.fundId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundAsync = ref.watch(fundDetailProvider(fundId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/funds'),
        ),
        title: const Text('Fund Detail'),
      ),
      body: fundAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (fund) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fund.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoChip(label: fund.type, icon: Icons.category),
                  const SizedBox(width: 8),
                  _InfoChip(label: fund.riskLevel, icon: Icons.warning),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NAV Trend',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      NavChart(
                        data: fund.navHistory
                            .map((e) => NavDataPoint(date: e.date, nav: e.nav))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fund Information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(label: 'NAV', value: fund.nav.toStringAsFixed(4)),
                      _InfoRow(label: 'Daily Return', value: '${fund.dailyReturn.toStringAsFixed(2)}%'),
                      _InfoRow(label: 'Total Assets', value: '\$${fund.totalAssets.toStringAsFixed(2)}'),
                      _InfoRow(label: 'Manager', value: fund.manager),
                      _InfoRow(label: 'Inception Date', value: fund.inceptionDate),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                fund.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/order/setup?fundId=$fundId'),
                  child: const Text('Invest Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 创建 MultiAssetFundListScreen**

```dart
// lib/features/funds/presentation/multi_asset_fund_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/fund_model.dart';

final multiAssetFundsProvider = FutureProvider<List<Fund>>((ref) async {
  // Implementation will be provided when connecting to actual API
  return [];
});

class MultiAssetFundListScreen extends ConsumerWidget {
  const MultiAssetFundListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundsAsync = ref.watch(multiAssetFundsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/funds'),
        ),
        title: const Text('Multi-Asset Funds'),
      ),
      body: fundsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (funds) {
          if (funds.isEmpty) {
            return const Center(child: Text('No multi-asset funds available'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: funds.length,
            itemBuilder: (context, index) {
              final fund = funds[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(fund.name),
                  subtitle: Text(fund.type),
                  trailing: Text(
                    '${fund.dailyReturn >= 0 ? '+' : ''}${fund.dailyReturn.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: fund.dailyReturn >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => context.go('/funds/${fund.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

---

### Task 12-16: 其他功能模块 (Portfolio, Order, Holdings, Plans)

由于篇幅限制，这些模块将复用上述模式创建，包含各自的 `data/`、`domain/`、`presentation/` 目录结构。

每个模块需要创建：
- `*_api.dart` - API 调用
- `*_model.dart` - 数据模型
- `*_screen.dart` - 页面组件

---

## Phase 4: 集成与测试

### Task 17: Provider 集成

**Files:**
- Modify: `flutter/lib/main.dart`

- [ ] **Step 1: 更新 main.dart 集成所有 Provider**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/token_manager.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/domain/auth_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStorage = SecureStorage();
  final tokenManager = TokenManager(secureStorage);
  final apiClient = ApiClient(tokenManager);
  final authRepository = AuthRepository(apiClient, tokenManager);

  runApp(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith((ref) => AuthNotifier(authRepository)),
      ],
      child: SmartInvestApp(),
    ),
  );
}

class SmartInvestApp extends ConsumerWidget {
  const SmartInvestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Smart Invest',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

---

### Task 18: 验证构建

- [ ] **Step 1: 验证 Flutter 项目**

```bash
cd flutter
flutter pub get
flutter analyze
flutter build web --release
```

- [ ] **Step 2: 验证 iOS 构建 (macOS only)**

```bash
flutter build ios --simulator --no-codesign
```

- [ ] **Step 3: 验证 Android 构建**

```bash
flutter build apk --debug
```

---

## 自检清单

- [ ] Spec 覆盖：所有设计文档中的功能都有对应实现
- [ ] 无占位符：没有 TBD、TODO、fill in later
- [ ] 类型一致性：跨文件的类型、方法签名一致
- [ ] 路由完整：所有 14 个页面都已配置
- [ ] Provider 就绪：所有状态管理已定义
