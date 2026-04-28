// lib/features/auth/presentation/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/auth_state.dart';
import '../domain/auth_notifier.dart';

// Brand colors matching React UI
class BrandColors {
  static const Color siRed = Color(0xFFE8341A);
  static const Color siOrange = Color(0xFFFF7043);
  static const Color siYellow = Color(0xFFFFC107);
  static const Color siDark = Color(0xFF1F2937);
  static const Color siGray = Color(0xFF6B7280);
  static const Color siBorder = Color(0xFFE5E7EB);
  static const Color siLight = Color(0xFFF9FAFB);
}

// SVG Logo as CustomPaint
class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [BrandColors.siRed, BrandColors.siOrange],
    );
    final paint = Paint()..shader = gradient.createShader(rect);

    // Rounded rectangle background
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, paint);

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final white60 = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final white80 = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // Bar chart bars
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(6, 18, 4, 8), const Radius.circular(1.5)),
        white60);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(12, 13, 4, 13), const Radius.circular(1.5)),
        white80);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(18, 9, 4, 17), const Radius.circular(1.5)),
        white);

    // Polyline stroke
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path1 = Path()
      ..moveTo(6, 17)
      ..lineTo(12, 12)
      ..lineTo(18, 8)
      ..lineTo(26, 5);
    canvas.drawPath(path1, strokePaint);

    final path2 = Path()
      ..moveTo(22, 5)
      ..lineTo(26, 5)
      ..lineTo(26, 9);
    canvas.drawPath(path2, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isEnglish = true;
  String? _errorMessage;

  // i18n key for login_platform - matching React's t('login_platform')
  // TODO: Replace with actual i18n integration when available
  static const String _loginPlatformText = '智能投资平台';

  // Focus nodes for auto-fill on focus
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onEmailFocus);
    _passwordFocusNode.addListener(_onPasswordFocus);
  }

  void _onEmailFocus() {
    if (_emailFocusNode.hasFocus && _emailController.text.isEmpty) {
      _emailController.text = 'demo@smartinvest.com';
    }
  }

  void _onPasswordFocus() {
    if (_passwordFocusNode.hasFocus && _passwordController.text.isEmpty) {
      _passwordController.text = 'Demo1234!';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _toggleLanguage() {
    setState(() {
      _isEnglish = !_isEnglish;
    });
  }

  Future<void> _launchGitHub() async {
    final url = Uri.parse('https://github.com/engineerping/smart-invest');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
          );
    } catch (e) {
      setState(() {
        _errorMessage = _isEnglish ? 'Login failed. Please check your credentials.' : '登录失败，请检查您的凭证。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/');
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Top bar: logo left, lang toggle right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CustomPaint(painter: LogoPainter()),
                  ),
                  GestureDetector(
                    onTap: _toggleLanguage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [BrandColors.siRed, BrandColors.siOrange],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: BrandColors.siRed.withOpacity(0.3),
                            blurRadius: 8,
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
                ],
              ),

              const SizedBox(height: 40),

              // Centered brand header
              Center(
                child: Column(
                  children: [
                    // Smart Invest trademark badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [BrandColors.siRed, BrandColors.siOrange, BrandColors.siYellow],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: BrandColors.siRed.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Smart Invest',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 3D title with ellipse shadow
                    Column(
                      children: [
                        const Text(
                          _loginPlatformText,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            color: Color(0xFFFF5722),
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                color: Color(0xFFE64A19),
                              ),
                              Shadow(
                                offset: Offset(2, 2),
                                color: Color(0xFFD84315),
                              ),
                              Shadow(
                                offset: Offset(3, 3),
                                color: Color(0xFFBF360C),
                              ),
                              Shadow(
                                offset: Offset(4, 4),
                                color: Color(0xFF8D2001),
                              ),
                              Shadow(
                                offset: Offset(0, 7),
                                color: Color(0xFFB4280A),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.75,
                          height: 16,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.5,
                              colors: [
                                const Color(0xFFDC3C14).withOpacity(0.52),
                                const Color(0xFFDC3C14).withOpacity(0.18),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.55, 0.8],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Gradient tagline box
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [BrandColors.siRed, BrandColors.siOrange, BrandColors.siYellow],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          _isEnglish
                              ? 'Your Smart Investment Partner'
                              : '您的智能投资伙伴',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..shader = const LinearGradient(
                                colors: [BrandColors.siRed, BrandColors.siOrange, BrandColors.siYellow],
                              ).createShader(const Rect.fromLTWH(0, 0, 200, 20)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Login form
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email field
                  Text(
                    _isEnglish ? 'Email' : '邮箱',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: BrandColors.siDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'demo@smartinvest.com',
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: BrandColors.siBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: BrandColors.siBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: BrandColors.siRed, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Password field
                  Text(
                    _isEnglish ? 'Password' : '密码',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: BrandColors.siDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Demo1234!',
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: BrandColors.siBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: BrandColors.siBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: BrandColors.siRed, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: BrandColors.siGray,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Error message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: authState.status == AuthStatus.loading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.siRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: authState.status == AuthStatus.loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isEnglish ? 'Login' : '登录',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isEnglish ? "Don't have an account? " : '没有账号？',
                    style: const TextStyle(
                      fontSize: 14,
                      color: BrandColors.siGray,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: Text(
                      _isEnglish ? 'Register' : '注册',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: BrandColors.siRed,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // GitHub link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'github: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: BrandColors.siDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _launchGitHub();
                    },
                    child: const Text(
                      'https://github.com/engineerping/smart-invest',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Made by
              Center(
                child: Text(
                  _isEnglish ? 'Made by Smart Invest Team' : '由Smart Invest团队制作',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: BrandColors.siDark,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}