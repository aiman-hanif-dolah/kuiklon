import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuiklon/git_service.dart';
import 'package:kuiklon/main.dart';
import 'package:kuiklon/settings_service.dart';

void main() {
  testWidgets('idle state shows hint, status and console placeholder', (
    tester,
  ) async {
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
      find.textContaining('could not parse a github repo'),
      findsOneWidget,
    );
  });

  testWidgets('typing a github url detects the repo name', (tester) async {
    await tester.pumpWidget(const KuiklonApp());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.byType(TextField),
      'https://github.com/user/hello-world',
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('hello-world'), findsOneWidget);
    // Either "new repo … ready to clone" or "already exists → ready to
    // pull / push", depending on the host machine.
    expect(find.textContaining('ready to'), findsOneWidget);
  });

  testWidgets('clone location dialog validates and persists', (tester) async {
    // Real file IO must run outside the fake-async zone.
    final tmp = await tester.runAsync(
      () => Directory.systemTemp.createTemp('kuiklon_widget_'),
    );
    expect(tmp, isNotNull);
    final tmpDir = tmp!;
    final prevOverride = SettingsService.baseDirOverride;
    final prevRoot = GitService.projectsRoot;
    addTearDown(() {
      SettingsService.baseDirOverride = prevOverride;
      GitService.projectsRoot = prevRoot;
      try {
        tmpDir.deleteSync(recursive: true);
      } on FileSystemException catch (_) {
        // Temp cleanup is best-effort.
      }
    });
    SettingsService.baseDirOverride = tmpDir.path;
    GitService.projectsRoot = r'C:\IdeaProjects';

    await tester.pumpWidget(const KuiklonApp());
    await tester.pump(const Duration(milliseconds: 200));

    // The header location tag opens the dialog.
    await tester.tap(find.text('C:/IdeaProjects'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Change clone location'), findsOneWidget);

    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    // Relative input is rejected and the dialog stays open.
    await tester.enterText(field, 'not-absolute');
    await tester.tap(find.text('save location'));
    await tester.pump();
    expect(find.textContaining('absolute path'), findsOneWidget);
    expect(find.text('Change clone location'), findsOneWidget);

    // A valid absolute path is applied, persisted and created.
    final newRoot = '${tmpDir.path}/newroot';
    await tester.enterText(field, newRoot);
    await tester.tap(find.text('save location'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Change clone location'), findsNothing);
    expect(GitService.projectsRoot, newRoot);
    expect(SettingsService.readProjectsRoot(), newRoot);
    expect(Directory(newRoot).existsSync(), isTrue);
    expect(find.text(newRoot.replaceAll('\\', '/')), findsOneWidget);
  });

  testWidgets('copy path button is present and copies target directory', (
    tester,
  ) async {
    await tester.pumpWidget(const KuiklonApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('copy root'), findsOneWidget);
    expect(find.text('open folder'), findsOneWidget);

    await tester.tap(find.text('copy root'));
    await tester.pump();

    expect(find.textContaining('copied:'), findsOneWidget);
  });
}

