import 'package:flutter/material.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

class AppbarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String appbarText;
  const AppbarWidget({super.key, required this.appbarText});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: Text(appbarText),
      titleTextStyle: ThemeTextStyle.appbarText,
      iconTheme: IconThemeData(
        color: ThemeColor.black,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}