import 'package:flutter/material.dart';
import '../features/home/widgets/home_header.dart';
import '../app.dart';

/// Cube-style AppBar used on all sub-screens.
/// Stacks the GNSS status header above a blue title bar.
class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const GlobalAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.showBackButton = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? kCubeBlue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // GNSS status + coordinate row
        HomeHeader(showBackButton: false),

        // Screen title bar
        Container(
          color: bgColor,
          child: AppBar(
            backgroundColor: bgColor,
            foregroundColor: foregroundColor ?? Colors.white,
            elevation: 0,
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                letterSpacing: 0.5,
              ),
            ),
            actions: actions,
            bottom: bottom,
            automaticallyImplyLeading: showBackButton,
            leading: showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null,
            primary: false,
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize {
    // GNSS status (~72px) + coordinate bar (~28px) + AppBar (56px) + bottom
    return Size.fromHeight(
        100.0 + 56.0 + (bottom?.preferredSize.height ?? 0.0));
  }
}
