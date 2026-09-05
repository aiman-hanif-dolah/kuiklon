import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuiklon/git_service.dart';

void main() {
  group('extractRepoName', () {
    test('parses standard github urls', () {
      expect(GitService.extractRepoName('https://github.com/user/some-repo.git'),
          'some-repo');
      expect(GitService.extractRepoName('git@github.com:user/repo.git'), 'repo');
      expect(GitService.extractRepoName('https://github.com/a/b/'), 'b');
      expect(GitService.extractRepoName('https://github.com/a/b'), 'b');
      expect(GitService.extractRepoName('https://github.com/a/b?tab=readme'),
          'b');
      expect(GitService.extractRepoName(' ssh://git@github.com/u/repo.git '),
          'repo');
    });

    test('parses deep github links to the repo name', () {
      expect(
          GitService.extractRepoName(
              'https://github.com/user/repo/tree/main'), 'repo');
      expect(
          GitService.extractRepoName(
              'https://github.com/user/repo/blob/main/lib/main.dart'),
          'repo');
      expect(
          GitService.extractRepoName(
              'https://github.com/user/repo/pull/12'), 'repo');
    });

    test('falls back to last path segment for non-github .git urls', () {
      expect(GitService.extractRepoName('https://gitlab.com/u/repo.git'),
          'repo');
      expect(GitService.extractRepoName(r'C:\code\my-project.git'),
          'my-project');
      expect(GitService.extractRepoName('/srv/git/team/thing.git'), 'thing');
    });

    test('rejects unsafe or unusable names', () {
      expect(GitService.extractRepoName(''), null);
      expect(GitService.extractRepoName('   '), null);
      expect(GitService.extractRepoName('not a url'), null);
      expect(GitService.extractRepoName('https://github.com/onlyowner'), null);
      // Traversal / reserved names must never become a folder name.
      expect(GitService.extractRepoName('https://github.com/u/..git'), null);
      expect(GitService.extractRepoName(r'..\..\.git'), null);
      expect(GitService.extractRepoName('https://github.com/u/.git'), null);
      expect(GitService.extractRepoName(r'C:\evil\..git'), null);
    });
  });

  group('repoName safety', () {
    test('repoPath keeps the name a single segment', () {
      final p = GitService.repoPath('ok_name-2.x');
      expect(p.contains('..'), isFalse);
      expect(p.contains(RegExp(r'[\\/]ok_name-2\.x$')), isTrue);
    });
  });

  group('git operations (local fixtures)', () {
    late Directory tmp;

    setUpAll(() async {
      tmp = await Directory.systemTemp.createTemp('kuiklon_test_');
      GitService.projectsRoot = tmp.path;
    });

    tearDownAll(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<void> git(String cwd, List<String> args) async {
      final r = await Process.run('git', args,
          workingDirectory: cwd, stdoutEncoding: utf8, stderrEncoding: utf8);
      expect(r.exitCode, 0,
          reason: 'git $args failed:\n${r.stdout}\n${r.stderr}');
    }

    test('clone creates the repo in projectsRoot', () async {
      // Seed a bare origin with one commit so the clone has an upstream.
      await git(tmp.path, ['init', 'seed']);
      final seed = '${tmp.path}/seed';
      await File('$seed/a.txt').writeAsString('one');
      await git(seed, ['add', '.']);
      await git(seed, ['-c', 'user.name=t', '-c', 'user.email=t@t',
        'commit', '-m', 'one']);
      await git(tmp.path, ['init', '--bare', 'origin.git']);
      await git(seed, ['push', '../origin.git', 'HEAD']);

      final res = await GitService.clone('${tmp.path}/origin.git');
      expect(res.success, isTrue, reason: res.output);
      expect(GitService.repoExists('origin'), isTrue);
    });

    test('cloning an existing repo fails with a clear message', () async {
      final res = await GitService.clone('${tmp.path}/origin.git');
      expect(res.success, isFalse);
      expect(res.message, contains('already exists'));
    });

    test('clone rejects invalid input without running git', () async {
      final res = await GitService.clone('not a git url');
      expect(res.success, isFalse);
      expect(res.message, 'Not a valid GitHub URL');
    });

    test('isDirty reflects the working tree', () async {
      final clonePath = GitService.repoPath('origin');
      expect(await GitService.isDirty('origin'), isFalse);
      await File('$clonePath/a.txt').writeAsString('changed');
      expect(await GitService.isDirty('origin'), isTrue);
      await git(clonePath, ['-c', 'user.name=t', '-c', 'user.email=t@t',
        'commit', '-am', 'dirty']);
    });

    test('isAhead is true before push and false after', () async {
      expect(await GitService.isAhead('origin'), isTrue);
      final res = await GitService.push('origin');
      expect(res.success, isTrue, reason: res.output);
      expect(await GitService.isAhead('origin'), isFalse);
    });

    test('pull brings in commits pushed from another clone', () async {
      final second = '${tmp.path}/second';
      await git(tmp.path, ['clone', 'origin.git', 'second']);
      await File('$second/b.txt').writeAsString('two');
      await git(second, ['add', '.']);
      await git(second, ['-c', 'user.name=t', '-c', 'user.email=t@t',
        'commit', '-m', 'two']);
      await git(second, ['push']);

      final res = await GitService.pull('origin');
      expect(res.success, isTrue, reason: res.output);
      expect(
          await File('${GitService.repoPath("origin")}/b.txt').exists(), isTrue);
    });

    test('streamed run emits output lines', () async {
      await git(tmp.path, ['init', '--bare', 'stream.git']);
      final lines = <String>[];
      final res =
          await GitService.clone('${tmp.path}/stream.git', onLine: lines.add);
      expect(res.success, isTrue, reason: res.output);
      expect(lines, isNotEmpty);
    });

    test('clone into a missing projectsRoot creates it and succeeds',
        () async {
      final fresh = '${tmp.path}/fresh-root';
      GitService.projectsRoot = fresh;
      final res = await GitService.clone('${tmp.path}/origin.git');
      expect(res.success, isTrue, reason: res.output);
      expect(Directory('$fresh/origin').existsSync(), isTrue);
      expect(GitService.repoExists('origin'), isTrue);
      GitService.projectsRoot = tmp.path;
    });
  });
}