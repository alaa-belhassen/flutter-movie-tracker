import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movietracker/features/users/presentation/login_page.dart';

void main() {
  testWidgets('keeps the sign-in form readable on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );

    expect(tester.getSize(find.byType(Card)).width, lessThanOrEqualTo(520));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Explore without account'), findsOneWidget);
  });
}
