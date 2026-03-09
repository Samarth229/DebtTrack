// Basic Flutter widget test for MyFinance app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myfinance/main.dart';
import 'package:myfinance/ui/screens/dashboard_screen.dart';

void main() {
  testWidgets('App loads dashboard screen', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const MyFinanceApp());

    // Verify that MaterialApp loads.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify that DashboardScreen is the home screen.
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
