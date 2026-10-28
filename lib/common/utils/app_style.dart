import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Comme le thème Ngoni : Poppins pour les titres (grands ou gras), Nunito
/// Sans pour le texte courant.
TextStyle appStyle(double size, Color color, FontWeight fw) {
  final width = ScreenUtil().screenWidth;
  final isLargeScreen = width >= 900;
  final fontSize = isLargeScreen ? size : size.sp;
  final isTitle = size >= 18 || fw.value >= FontWeight.w700.value;
  return isTitle
      ? GoogleFonts.poppins(fontSize: fontSize, color: color, fontWeight: fw)
      : GoogleFonts.nunitoSans(
          fontSize: fontSize,
          color: color,
          fontWeight: fw,
        );
}
