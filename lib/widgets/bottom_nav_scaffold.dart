import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'app_drawer.dart';

class BottomNavScaffold extends StatelessWidget {
  const BottomNavScaffold({
    super.key,
    required this.child,
    this.showDrawer = true,
  });

  final Widget child;
  final bool showDrawer;

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Scaffold(
      extendBody: true,
      backgroundColor: kBg,

      // ✅ Drawer global (si lo quieres en todas)
      drawer: showDrawer
          ? AppDrawer(
              currentRoute: currentRoute,
              brand: kBrand,
              logoPath: 'assets/images/orbird_ai_blanco.png',
              appName: 'OrBird AI',
            )
          : null,

      body: child,
    );
  }
}
