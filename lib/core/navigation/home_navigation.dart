import 'package:flutter/material.dart';

final homeRequests = ValueNotifier<int>(0);

class HomeNavigationObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    homeRequests.value++;
  }
}

final homeNavigationObserver = HomeNavigationObserver();
