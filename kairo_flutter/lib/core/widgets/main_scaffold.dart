import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/kairo_colors.dart';
import 'bottom_navigation.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({
    super.key,
    required this.child,
    this.showBottomNav = true,
    this.appBar,
  });

  final Widget child;
  final bool showBottomNav;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: KairoColors.darkBg,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: KairoColors.darkBg,
        appBar: appBar,
        body: child,
        bottomNavigationBar: showBottomNav ? KairoBottomNavigation(currentPath: path) : null,
      ),
    );
  }
}
