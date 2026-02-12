import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

TextStyle appStyle(double size, Color color, FontWeight fw) {
  final width = ScreenUtil().screenWidth;
  final isLargeScreen = width >= 900;
  final fontSize = isLargeScreen ? size : size.sp;
  return GoogleFonts.poppins(fontSize: fontSize, color: color, fontWeight: fw);
}
