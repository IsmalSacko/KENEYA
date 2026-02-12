import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:keneya_plus/common/utils/kcolors.dart';
import 'package:keneya_plus/core/storage/token_storage.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.color, this.size, this.onTap});

  final Color? color;
  final double? size;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            GoRouter.of(context).go('/dashboard');
          },
      child: Icon(
        AntDesign.leftcircle,
        color: color ?? Kolors.kPrimary,
        size: size ?? 28,
      ),
    );
  }
}

Future<bool> isAuthenticated() async {
  final token = await TokenStorage.getToken();
  return token != null && token.isNotEmpty;
}
