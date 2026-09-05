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

/// Handle for a running git operation, used to cancel it.
class GitProcessHandle {
  Process? _process;
  bool cancelled = false;

  void cancel() {
    cancelled = true;
    _process?.kill();
  }
}

class GitService {
  /// Overridable so tests can run git against a temp directory.
  static String projectsRoot = r'C:\IdeaProjects';

  static GitProcessHandle? _active;

  /// Cancels the currently running git operation, if any.
  static void cancelActive() => _active?.cancel();

  static String? extractRepoName(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    String? raw;
    // github.com URLs: https or ssh (git@github.com:owner/repo), optionally
    // with deeper paths (/tree/main, /blob/main/x.dart) — owner/repo is all
    // that matters for locating the repo.
    final m = RegExp(r'github\.com[/:]([\w.-]+)/([\w.-]+)').firstMatch(s);
    if (m != null) {
      raw = m.group(2);
    } else if (RegExp(r'\.git$', caseSensitive: false).hasMatch(s)) {
      // Non-github git URLs / local paths: last path segment.
      raw = s.split(RegExp(r'[\\/]')).last;
    }
    if (raw == null) return null;
    // The .git suffix is case-insensitive on git hosts (Repo.GIT).
    final gitSuffix = RegExp(r'\.git$', caseSensitive: false).firstMatch(raw);
    if (gitSuffix != null && raw.length > 4) {
      raw = raw.substring(0, gitSuffix.start);
    }
    // The name becomes a folder under projectsRoot, so restrict it to a safe
    // single path segment: no traversal, no separators, no leading dots, and
    // no trailing dots (Windows cannot create a folder named "x.").
    if (raw.isEmpty || raw.startsWith('.') || raw.endsWith('.')) {
      return null;
    }
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(raw)) return null;
    return raw;
  }

  static String repoPath(String repoName) => Platform.pathSeparator == '\\'
      ? '$projectsRoot\\$repoName'
      : '$projectsRoot/$repoName';

  static bool repoExists(String repoName) =>
      Directory(repoPath(repoName)).existsSync();

  static void ensureProjectsRoot() {
    final dir = Directory(projectsRoot);
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }

  static Future<GitResult> _run(
    String workingDir,
    List<String> args,
    OpType type, {
    void Function(String line)? onLine,
  }) async {
    final handle = GitProcessHandle();
    _active = handle;
    final buf = <String>[];
    try {
      final proc = await Process.start(
        'git',
        args,
        workingDirectory: workingDir,
        environment: _gitEnv(),
      );
      handle._process = proc;
      if (handle.cancelled) proc.kill();
      void emit(String line) {
        buf.add(line);
        onLine?.call(line);
      }

      final subs = <StreamSubscription<String>>[
        proc.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(emit),
        proc.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(emit),
      ];
      await Future.wait(subs.map((s) => s.asFuture<void>()));
      final code = await proc.exitCode;
      // Only report a cancellation if the process did not finish cleanly;
      // a cancel arriving after natural completion must not misreport it.
      if (handle.cancelled && code != 0) {
        return GitResult(false, 'Cancelled', buf.join('\n'));
      }
      final ok = code == 0;
      return GitResult(
        ok,
        _resultMessage(type, ok, code, buf),
        buf.join('\n').trim(),
      );
    } catch (e) {
      return GitResult(false, 'Failed to run git', e.toString());
    } finally {
      if (identical(_active, handle)) _active = null;
    }
  }

  // Git must never sit waiting for credentials it cannot receive: without
  // this, private repos would hang the app on a prompt.
  static Map<String, String> _gitEnv() => {'GIT_TERMINAL_PROMPT': '0'};

  static String _resultMessage(
    OpType type,
    bool ok,
    int code,
    List<String> buf,
  ) {
    if (!ok) return 'git ${type.name} failed (exit $code)';
    return switch (type) {
      OpType.clone => 'Cloned successfully',
      OpType.pull =>
        buf.any((l) => l.contains('Already up to date'))
            ? 'Already up to date'
            : 'Pulled successfully',
      OpType.push => 'Pushed successfully',
    };
  }

  static Future<GitResult> clone(
    String url, {
    void Function(String line)? onLine,
  }) async {
    final name = extractRepoName(url);
    if (name == null) {
      return GitResult(false, 'Not a valid GitHub URL', '');
    }
    if (repoExists(name)) {
      return GitResult(false, '"$name" already exists in $projectsRoot', '');
    }
    ensureProjectsRoot();
    // '--' so a pasted string can never be parsed as a git option.
    return _run(
      projectsRoot,
      ['clone', '--', url.trim()],
      OpType.clone,
      onLine: onLine,
    );
  }

  static Future<GitResult> pull(
    String repoName, {
    void Function(String line)? onLine,
  }) => _run(repoPath(repoName), ['pull'], OpType.pull, onLine: onLine);

  static Future<GitResult> push(
    String repoName, {
    void Function(String line)? onLine,
  }) => _run(repoPath(repoName), ['push'], OpType.push, onLine: onLine);

  static Future<bool> isDirty(String repoName) async {
    try {
      final p = await Process.run(
        'git',
        ['status', '--porcelain'],
        workingDirectory: repoPath(repoName),
        stdoutEncoding: utf8,
        environment: _gitEnv(),
      );
      return p.exitCode == 0 && (p.stdout as String).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAhead(String repoName) async {
    try {
      final p = await Process.run(
        'git',
        ['rev-list', '--count', '@{u}..HEAD'],
        workingDirectory: repoPath(repoName),
        stdoutEncoding: utf8,
        environment: _gitEnv(),
      );
      final n = int.tryParse((p.stdout as String).trim());
      return p.exitCode == 0 && n != null && n > 0;
    } catch (_) {
      return false;
    }
  }
}
