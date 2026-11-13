import 'package:flutter/material.dart';

final homeRequests = ValueNotifier<int>(0);

class HomeNavigationObserver extends NavigatorObserver {
  bool _returning = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    if (_returning) return;
    _returning = true;
    Future.microtask(() {
      homeRequests.value++;
      navigator?.popUntil((route) => route.isFirst);
      _returning = false;
    });
  }
}

final homeNavigationObserver = HomeNavigationObserver();
