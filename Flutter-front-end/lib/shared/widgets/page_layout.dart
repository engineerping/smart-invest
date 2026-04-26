// lib/shared/widgets/page_layout.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PageLayout extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool showBack;

  const PageLayout({
    super.key,
    required this.child,
    this.title,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (title != null) _buildHeader(context),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              onTap: () => context.pop(),
              child: const Text('‹', style: TextStyle(fontSize: 24, color: Color(0xFF6B7280))),
            ),
          if (showBack) const SizedBox(width: 12),
          Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }
}
