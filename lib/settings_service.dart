import 'dart:convert';
import 'dart:io';

/// Persists user preferences as JSON under %APPDATA%\Kuiklon.
///
/// Deliberately dependency-free (dart:io only) and synchronous: the settings
/// file is a few bytes and is read once at startup. `baseDirOverride` lets
/// tests point persistence at a temp directory.
class SettingsService {
  /// Overrides the directory the settings file lives in (tests only).
  static String? baseDirOverride;

  static Directory get _dir {
    if (baseDirOverride != null) return Directory(baseDirOverride!);
    final base = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
    return Directory(base);
  }

  static File get _settingsFile => File(
    '${_dir.path}${Platform.pathSeparator}Kuiklon${Platform.pathSeparator}settings.json',
  );

  /// Returns the persisted clone location, or null when unset/unreadable.
  /// A missing file (first run) or a corrupted file must never break startup,
  /// so both fall back to the defaults.
  static String? readProjectsRoot() {
    try {
      final map = jsonDecode(_settingsFile.readAsStringSync());
      final root = map is Map ? map['projectsRoot'] : null;
      if (root is String && root.trim().isNotEmpty) {
        return normalizePath(root);
      }
    } on FormatException catch (_) {
      // Corrupted settings: fall back to defaults.
    } on FileSystemException catch (_) {
      // No settings file yet (first run).
    }
    return null;
  }

  static void writeProjectsRoot(String path) {
    final p = normalizePath(path);
    _settingsFile.parent.createSync(recursive: true);
    _settingsFile.writeAsStringSync(jsonEncode({'projectsRoot': p}));
  }

  /// Collapses trailing separators while keeping drive roots intact
  /// ('C:\code\' → 'C:\code', 'C:\' stays 'C:\').
  static String normalizePath(String raw) {
    var p = raw.trim();
    while (p.length > 3 && (p.endsWith('\\') || p.endsWith('/'))) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  /// Returns an error message for an unusable clone location, or null when
  /// the input is acceptable.
  static String? validateProjectsRoot(String input) {
    final p = normalizePath(input);
    if (p.isEmpty) return 'enter a folder path';
    final absolute = Platform.isWindows
        ? RegExp(r'^([A-Za-z]:[\\/]|\\\\)').hasMatch(p)
        : p.startsWith('/');
    if (!absolute) return 'use an absolute path like C:\\dev\\projects';
    return null;
  }
}
