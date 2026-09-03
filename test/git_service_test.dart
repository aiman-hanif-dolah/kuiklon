import 'package:flutter_test/flutter_test.dart';
import 'package:kuiklon/git_service.dart';

void main() {
  test('extractRepoName parses github urls', () {
    expect(
        GitService.extractRepoName(
            'https://github.com/user/some-repo.git'),
        'some-repo');
    expect(GitService.extractRepoName('git@github.com:user/repo.git'),
        'repo');
    expect(GitService.extractRepoName('https://github.com/a/b/'), 'b');
  });
}