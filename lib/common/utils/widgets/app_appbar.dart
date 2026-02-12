import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_style.dart';
import '../kcolors.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBusinessAction;
  final List<Widget>? actions;
  final VoidCallback? onBusinessTap;

  const AppAppBar({
    super.key,
    required this.title,
    this.showBusinessAction = true,
    this.actions,
    this.onBusinessTap,
  });

  Future<String?> _loadActiveBusinessLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('last_business_id');
    final name = prefs.getString('last_business_name');

    if (name != null && name.trim().isNotEmpty) return name;
    if (id == null) return null;

    return 'Business #$id';
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Kolors.kPrimary,
      elevation: 0,
      title: Text(title, style: appStyle(24, Kolors.kWhite, FontWeight.bold)),
      actions: showBusinessAction
          ? [
              FutureBuilder<String?>(
                future: _loadActiveBusinessLabel(),
                builder: (context, snapshot) {
                  final businessLabel = snapshot.data ?? 'Choisir un business';

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
                      onPressed: onBusinessTap,
                      icon: const Icon(
                        Icons.business_center_outlined,
                        color: Kolors.kGreen,
                        size: 30,
                      ),
                      label: Text(
                        businessLabel,
                        overflow: TextOverflow.ellipsis,
                        style: appStyle(14, Kolors.kWhite, FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Kolors.kWhite,
                      ),
                    ),
                  );
                },
              ),
              ...?actions,
            ]
          : actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
