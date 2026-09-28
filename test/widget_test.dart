import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tresuremap/features/webview/widgets/shiny_loader.dart';

void main() {
  testWidgets('ShinyLoader renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: ShinyLoader()))),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ShinyLoader), findsOneWidget);
  });
}
