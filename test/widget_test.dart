import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura_svn/main.dart';

void main() {
  testWidgets('Dashboard shows loading state', (tester) async {
    await tester.pumpWidget(const SvnBranchViewerApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
