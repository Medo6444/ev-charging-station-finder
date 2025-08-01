import 'package:flutter/cupertino.dart';
import 'package:grad02/firebase/auth_services.dart';
import '../pages/app_loading_page.dart';
import '../pages/main_map_page.dart';
import '../pages/welcome_page.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, this.pageIfNotConnected});

  final Widget? pageIfNotConnected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: authService,
      builder: (context, authService, child) {
        return StreamBuilder(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            Widget widget;
            if (snapshot.connectionState == ConnectionState.waiting) {
              widget = AppLoadingPage();
            } else if (snapshot.hasData) {
              widget = const MapScreen();
            } else {
              widget = pageIfNotConnected ?? const WelcomePage();
            }
            return widget;
          },
        );
      },
    );
  }
}
