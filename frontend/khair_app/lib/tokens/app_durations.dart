import 'package:flutter/material.dart';

class AppDurations {
  AppDurations._();

  static const Duration micro = Duration(milliseconds: 120);
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration long = Duration(milliseconds: 360);

  static const Duration pageTransition = Duration(milliseconds: 320);
  static const Duration modalTransition = Duration(milliseconds: 260);
}

class AppCurves {
  AppCurves._();

  static const Curve standard = Curves.easeOut;
  static const Curve emphasized = Curves.easeOutCubic;
}
