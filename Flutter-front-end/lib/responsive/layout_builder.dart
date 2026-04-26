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
