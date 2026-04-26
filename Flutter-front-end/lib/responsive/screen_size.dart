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
