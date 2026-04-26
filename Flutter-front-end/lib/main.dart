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
