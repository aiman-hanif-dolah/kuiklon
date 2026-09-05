import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuiklon/main.dart';

void main() {
  testWidgets('idle state shows hint, status and console placeholder',
      (tester) async {
    await tester.pumpWidget(const KuiklonApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Kuiklon'), findsOneWidget);
    expect(find.text('awaiting input —'), findsOneWidget);
    expect(find.textContaining('output will stream here'), findsOneWidget);
    expect(find.text('clone'), findsOneWidget);
  });

  testWidgets('empty input shows a validation error', (tester) async {
    await tester.pumpWidget(const KuiklonApp());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.textContaining('paste a github repo link'), findsOneWidget);
  });

  testWidgets('unparseable input shows a parse error', (tester) async {
    await tester.pumpWidget(const KuiklonApp());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(
        find.textContaining('could not parse a github repo'), findsOneWidget);
  });

  testWidgets('typing a github url detects the repo name', (tester) async {
    await tester.pumpWidget(const KuiklonApp());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
        find.byType(TextField), 'https://github.com/user/hello-world');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('hello-world'), findsOneWidget);
    // Either "new repo … ready to clone" or "already exists → ready to
    // pull / push", depending on the host machine.
    expect(find.textContaining('ready to'), findsOneWidget);
  });
}