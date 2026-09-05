import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kuiklon/git_service.dart';
import 'package:kuiklon/main.dart';

/// Runs the real app on the real Windows desktop target and drives the
/// primary user flows end-to-end: paste URL → clone, and paste URL of an
/// existing repo → auto sync. Git operations hit local bare-repo fixtures
/// in a temp directory; the user's C:\IdeaProjects is never touched.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('kuiklon_it_');
    GitService.projectsRoot = tmp.path;

    Future<void> git(String cwd, List<String> args) async {
      final r = await Process.run('git', args, workingDirectory: cwd);
      if (r.exitCode != 0) {
        throw StateError('git $args failed: ${r.stderr}');
      }
    }

    // Seed a bare origin with one commit so clones have an upstream.
    await git(tmp.path, ['init', 'seed']);
    final seed = '${tmp.path}/seed';
    await File('$seed/a.txt').writeAsString('one');
    await git(seed, ['add', '.']);
    await git(seed, [
      '-c',
      'user.name=t',
      '-c',
      'user.email=t@t',
      'commit',
      '-m',
      'one',
    ]);
    await git(tmp.path, ['init', '--bare', 'origin.git']);
    await git(seed, ['push', '../origin.git', 'HEAD']);
  });

  tearDownAll(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  testWidgets('paste local git URL → clone succeeds through the real UI', (
    tester,
  ) async {
    await tester.pumpWidget(const KuiklonApp());
    await tester.pump(const Duration(seconds: 1));

    final url = '${tmp.path}/origin.git';
    await tester.enterText(find.byType(TextField), url);
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('origin'),
      findsOneWidget,
      reason: 'detected repo name should show in the field suffix',
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(
      find.text('working'),
      findsOneWidget,
      reason: 'primary button should enter the busy state',
    );
    expect(
      find.text('cancel'),
      findsOneWidget,
      reason: 'cancel affordance should appear while a git op runs',
    );

    var cloned = false;
    for (var i = 0; i < 120 && !cloned; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      cloned = find.textContaining('Cloned successfully').evaluate().isNotEmpty;
    }
    expect(cloned, isTrue, reason: 'clone never reached the done state');

    expect(find.text('cancel'), findsNothing);
    expect(
      GitService.repoExists('origin'),
      isTrue,
      reason: 'clone must land inside the projects root',
    );
    expect(
      find.textContaining('Cloning into'),
      findsWidgets,
      reason: 'git output should have streamed into the console',
    );
  });

  testWidgets('paste URL of existing repo → auto sync runs', (tester) async {
    await tester.pumpWidget(const KuiklonApp());
    await tester.pump(const Duration(seconds: 1));

    final url = '${tmp.path}/origin.git';
    await tester.enterText(find.byType(TextField), url);
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('sync'),
      findsOneWidget,
      reason: 'existing repo should switch the primary action to sync',
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    var finished = false;
    for (var i = 0; i < 120 && !finished; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      finished = find.text('working').evaluate().isEmpty;
    }
    expect(finished, isTrue, reason: 'sync never returned to an idle phase');
    expect(find.text('cancel'), findsNothing);
    expect(
      find.text('pull'),
      findsOneWidget,
      reason: 'done state should offer manual pull/push again',
    );
    expect(find.text('push'), findsOneWidget);
    expect(GitService.repoExists('origin'), isTrue);
  });
}
