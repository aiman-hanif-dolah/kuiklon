import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum OpType { clone, pull, push }

class GitResult {
  final bool success;
  final String message;
  final String output;
  GitResult(this.success, this.message, this.output);
}

class GitService {
  static const String projectsRoot = r'C:\IdeaProjects';

  static String? extractRepoName(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    var m = RegExp(r'github\.com[/:]([\w.-]+)/([\w.-]+?)(?:\.git)?/?$')
        .firstMatch(s);
    if (m != null) return m.group(2);
    if (s.endsWith('.git')) return s.split(Platform.pathSeparator).last;
    return null;
  }

  static String repoPath(String repoName) =>
      Platform.pathSeparator == '\\' ? '$projectsRoot\\$repoName' : '$projectsRoot/$repoName';

  static bool repoExists(String repoName) =>
      Directory(repoPath(repoName)).existsSync();

  static Future<GitResult> _run(
      String workingDir, List<String> args, OpType type) async {
    try {
      final proc = await Process.run('git', args,
          workingDirectory: workingDir,
          stdoutEncoding: utf8,
          stderrEncoding: utf8);
      final out =
          ('${proc.stdout}\n${proc.stderr}').trim();
      final ok = proc.exitCode == 0;
      final msg = ok
          ? {
              OpType.clone: 'Cloned successfully',
              OpType.pull: 'Pulled — up to date',
              OpType.push: 'Pushed successfully',
            }[type]!
          : 'git ${args.first} failed (exit ${proc.exitCode})';
      return GitResult(ok, msg, out);
    } catch (e) {
      return GitResult(false, 'Failed to run git', e.toString());
    }
  }

  static Future<GitResult> clone(String url) async {
    final name = extractRepoName(url);
    if (name == null) {
      return GitResult(false, 'Not a valid GitHub URL', '');
    }
    if (repoExists(name)) {
      return GitResult(false, '"$name" already exists in $projectsRoot', '');
    }
    return _run(projectsRoot, ['clone', url.trim()], OpType.clone);
  }

  static Future<GitResult> pull(String repoName) =>
      _run(repoPath(repoName), ['pull'], OpType.pull);

  static Future<GitResult> push(String repoName) =>
      _run(repoPath(repoName), ['push'], OpType.push);

  static Future<String?> detectBranch(String repoName) async {
    try {
      final p = await Process.run('git',
          ['rev-parse', '--abbrev-ref', 'HEAD'],
          workingDirectory: repoPath(repoName),
          stdoutEncoding: utf8);
      if (p.exitCode == 0) return (p.stdout as String).trim();
    } catch (_) {}
    return null;
  }

  static Future<bool> hasUpstream(String repoName) async {
    try {
      final p = await Process.run('git',
          ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'],
          workingDirectory: repoPath(repoName),
          stdoutEncoding: utf8);
      return p.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasRemote(String repoName) async {
    try {
      final p = await Process.run('git', ['remote'],
          workingDirectory: repoPath(repoName),
          stdoutEncoding: utf8);
      return p.exitCode == 0 && (p.stdout as String).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isDirty(String repoName) async {
    try {
      final p = await Process.run('git', ['status', '--porcelain'],
          workingDirectory: repoPath(repoName),
          stdoutEncoding: utf8);
      return p.exitCode == 0 &&
          (p.stdout as String).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAhead(String repoName) async {
    try {
      final p = await Process.run('git',
          ['rev-list', '--count', '@{u}..HEAD'],
          workingDirectory: repoPath(repoName),
          stdoutEncoding: utf8);
      return p.exitCode == 0 &&
          int.tryParse((p.stdout as String).trim()) != null &&
          int.parse((p.stdout as String).trim()) > 0;
    } catch (_) {
      return false;
    }
  }
}