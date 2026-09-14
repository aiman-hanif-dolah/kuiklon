import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuiklon/settings_service.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kuiklon_settings_');
    SettingsService.baseDirOverride = tmp.path;
  });

  tearDown(() async {
    SettingsService.baseDirOverride = null;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('write then read round-trips the clone location', () {
    SettingsService.writeProjectsRoot(r'C:\dev\projects');
    expect(SettingsService.readProjectsRoot(), r'C:\dev\projects');
  });

  test('returns null when no settings file exists (first run)', () {
    expect(SettingsService.readProjectsRoot(), isNull);
  });

  test('returns null instead of crashing on a corrupted file', () {
    final dir = '${tmp.path}/Kuiklon';
    Directory(dir).createSync(recursive: true);
    File('$dir/settings.json').writeAsStringSync('{not json');
    expect(SettingsService.readProjectsRoot(), isNull);
  });

  test('ignores wrong-typed values in the settings file', () {
    final dir = '${tmp.path}/Kuiklon';
    Directory(dir).createSync(recursive: true);
    File(
      '$dir/settings.json',
    ).writeAsStringSync(jsonEncode({'projectsRoot': 42}));
    expect(SettingsService.readProjectsRoot(), isNull);
  });

  test('normalizePath trims trailing separators but keeps drive roots', () {
    expect(SettingsService.normalizePath(r'C:\code\'), r'C:\code');
    expect(SettingsService.normalizePath('C:\\\\'), 'C:\\');
    expect(SettingsService.normalizePath('  /srv/git/  '), '/srv/git');
    expect(SettingsService.normalizePath(r'C:\'), r'C:\');
  });

  test('validateProjectsRoot accepts absolute paths', () {
    expect(SettingsService.validateProjectsRoot(r'C:\dev\projects'), isNull);
    expect(SettingsService.validateProjectsRoot('c:/dev'), isNull);
  });

  test('validateProjectsRoot rejects empty and relative input', () {
    expect(SettingsService.validateProjectsRoot(''), isNotNull);
    expect(SettingsService.validateProjectsRoot('   '), isNotNull);
    expect(SettingsService.validateProjectsRoot('relative\\path'), isNotNull);
  });
}
