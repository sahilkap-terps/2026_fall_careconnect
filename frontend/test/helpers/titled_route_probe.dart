// Test helper: records the pages a widget pushes and reads their window
// titles, without building the destination pages (many need real services).
import 'package:care_connect_app/widgets/page_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TitledRouteProbe extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);

  /// Taps [finder] and returns the title of the TitledMaterialPageRoute it
  /// pushed, or null if it pushed something else. The pushed route is removed
  /// before the next frame, so the destination page is never built.
  Future<String?> tapAndReadTitle(WidgetTester tester, Finder finder) async {
    final before = pushed.length;
    await tester.tap(finder);
    expect(pushed.length, greaterThan(before),
        reason: 'tapping should push a page');
    final route = pushed.last;
    String? title;
    if (route is TitledMaterialPageRoute) {
      final context = navigator!.context;
      final content = route.buildContent(context);
      expect(content, isA<PageTitle>());
      title = (content as PageTitle).title;
    }
    navigator!.removeRoute(route);
    await tester.pump();
    return title;
  }
}
