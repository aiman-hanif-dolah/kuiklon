import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'git_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const opts = WindowOptions(
    title: 'Kuiklon',
    minimumSize: Size(860, 560),
    size: Size(980, 660),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const KuiklonApp());
}

class KuiklonApp extends StatelessWidget {
  const KuiklonApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kuiklon',
      debugShowCheckedModeBanner: false,
      theme: KTheme.dark(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

enum AppPhase { idle, busy, done, error }

class _HomePageState extends State<HomePage> with WindowListener {
  final _urlCtrl = TextEditingController();
  final _urlFocus = FocusNode();
  final _tray = SystemTray();
  final _appWindow = AppWindow();
  AppPhase _phase = AppPhase.idle;
  String _statusLine = '';
  String _output = '';
  String? _detectedName;
  bool _manualVisible = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _urlCtrl.addListener(_onUrlChanged);
    _initTray();
  }

  Future<void> _initTray() async {
    await _tray.initSystemTray(
      iconPath: 'assets/kuiklon_tray.ico',
      toolTip: 'Kuiklon — quick clone',
    );
    final menu = Menu()
      ..buildFrom([
        MenuItemLabel(
            label: 'Show Kuiklon', onClicked: (_) => _appWindow.show()),
        MenuSeparator(),
        MenuItemLabel(
            label: 'Open C:/IdeaProjects',
            onClicked: (_) async =>
                await Process.run('explorer.exe', [GitService.projectsRoot])),
        MenuSeparator(),
        MenuItemLabel(label: 'Quit Kuiklon', onClicked: (_) async {
          await _tray.destroy();
          await windowManager.destroy();
        }),
      ]);
    await _tray.setContextMenu(menu);
    _tray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        _appWindow.show();
      } else if (eventName == kSystemTrayEventRightClick) {
        _tray.popUpContextMenu();
      }
    });
  }

  @override
  void onWindowClose() async {
    await _appWindow.hide();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        _urlFocus.hasFocus) {
      _run();
      return true;
    }
    return false;
  }

  void _onUrlChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      setState(() {
        _detectedName = GitService.extractRepoName(_urlCtrl.text);
        if (_detectedName != null &&
            GitService.repoExists(_detectedName!)) {
          _statusLine =
              'repo already exists → ready to pull / push';
        } else if (_detectedName != null) {
          _statusLine = 'new repo detected → ready to clone';
        }
      });
    });
  }

  Future<void> _run() async {
    if (_phase == AppPhase.busy) return;
    final input = _urlCtrl.text.trim();
    if (input.isEmpty) {
      setState(() {
        _phase = AppPhase.error;
        _statusLine = 'paste a github repo link first';
      });
      return;
    }
    final name = GitService.extractRepoName(input);
    if (name == null) {
      setState(() {
        _phase = AppPhase.error;
        _statusLine = 'could not parse a github repo from that';
      });
      return;
    }
    setState(() {
      _phase = AppPhase.busy;
      _output = '';
    });

    final exists = GitService.repoExists(name);
    GitResult res;
    if (exists) {
      // Auto flow: pull first, then push local commits.
      res = await GitService.pull(name);
      if (res.success) {
        setState(() {
          _statusLine = res.message;
          _output = res.output;
        });
        final dirty = await GitService.isDirty(name);
        final ahead = await GitService.isAhead(name);
        if (dirty || ahead) {
          final pushRes = await GitService.push(name);
          setState(() {
            _statusLine = pushRes.success
                ? 'pulled ✓ → pushed ✓'
                : 'pulled ✓ → push: ${pushRes.message}';
            _output += '\n─ push ─\n${pushRes.output}';
            _phase = pushRes.success ? AppPhase.done : AppPhase.error;
          });
        } else {
          setState(() => _phase = AppPhase.done);
        }
      } else {
        setState(() {
          _statusLine = res.message;
          _output = res.output;
          _phase = AppPhase.error;
        });
      }
    } else {
      res = await GitService.clone(input);
      setState(() {
        _statusLine = res.message;
        _output = res.output;
        _phase = res.success ? AppPhase.done : AppPhase.error;
      });
    }
  }

  Future<void> _manual(OpType op) async {
    if (_phase == AppPhase.busy) return;
    final name = _detectedName;
    if (name == null) return;
    if (!GitService.repoExists(name)) return;
    setState(() {
      _phase = AppPhase.busy;
      _output = '';
      _statusLine = 'running git ${op.name}…';
    });
    final res = op == OpType.pull
        ? await GitService.pull(name)
        : await GitService.push(name);
    setState(() {
      _statusLine = res.message;
      _output = res.output;
      _phase = res.success ? AppPhase.done : AppPhase.error;
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _urlCtrl.dispose();
    _urlFocus.dispose();
    _debounce?.cancel();
    _tray.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exists = _detectedName != null && GitService.repoExists(_detectedName!);
    _manualVisible = _detectedName != null &&
        exists &&
        _phase != AppPhase.busy;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF131318), KColors.inkBg],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 28, 40, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(exists),
              const SizedBox(height: 26),
              _inputRow(),
              const SizedBox(height: 14),
              _statusStrip(),
              const SizedBox(height: 14),
              Expanded(child: _console()),
              const SizedBox(height: 14),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(bool exists) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset('assets/kuiklon_logo.png', width: 44, height: 44),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kuiklon',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8)),
            Text('fast clone · pull · push',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: KColors.textSecondary)),
          ],
        ),
        const Spacer(),
        _tag('C:/IdeaProjects', warm: true),
        const SizedBox(width: 8),
        _tag(exists ? 'repo exists' : 'ready', warm: exists),
      ],
    );
  }

  Widget _tag(String text, {bool warm = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: warm
            ? KColors.warm.withValues(alpha: 0.12)
            : KColors.inkElevated,
        border: Border.all(
            color: warm ? KColors.warmDeep : KColors.inkBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: warm ? KColors.warm : KColors.textSecondary)),
    );
  }

  Widget _inputRow() {
    final busy = _phase == AppPhase.busy;
    final exists =
        _detectedName != null && GitService.repoExists(_detectedName!);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _urlCtrl,
            focusNode: _urlFocus,
            enabled: !busy,
            autofocus: true,
            style: const TextStyle(
                fontFamily: 'JetBrainsMono', fontSize: 15),
            decoration: InputDecoration(
              hintText: 'https://github.com/user/repo.git',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 10),
                child: Icon(Icons.terminal, size: 20, color: KColors.textMuted),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              suffixIcon: _detectedName != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          _detectedName!,
                          style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 12,
                              color: exists
                                  ? KColors.warm
                                  : KColors.lime),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: busy ? null : _run,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Color(0xFF0C0C10)))
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(busy ? 'working' : 'clone'),
          ),
        ),
      ],
    );
  }

  Widget _statusStrip() {
    final color = switch (_phase) {
      AppPhase.idle => KColors.textMuted,
      AppPhase.busy => KColors.warm,
      AppPhase.done => KColors.lime,
      AppPhase.error => KColors.red,
    };
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _statusLine.isEmpty ? 'awaiting input —' : _statusLine,
            style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_manualVisible) ...[
          const SizedBox(width: 10),
          OutlinedButton.icon(
              onPressed: () => _manual(OpType.pull),
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('pull')),
          const SizedBox(width: 8),
          OutlinedButton.icon(
              onPressed: () => _manual(OpType.push),
              icon: const Icon(Icons.upload_rounded, size: 15),
              label: const Text('push')),
        ],
      ],
    );
  }

  Widget _console() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: KColors.inkSurface,
        border: Border.all(color: KColors.inkBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Text('\$ git',
                    style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: KColors.lime)),
                const SizedBox(width: 8),
                Text('output',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(letterSpacing: 2)),
                const Spacer(),
                Text('kuiklon v1.0',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          Divider(height: 1, color: KColors.inkBorder),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text(
                  _output.isEmpty
                      ? '# paste a link, press clone.\n# output will stream here.'
                      : _output,
                  style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.5,
                      height: 1.55,
                      color: _output.isEmpty
                          ? KColors.textMuted
                          : KColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Row(
      children: [
        Text('enter ⏎ runs · close ✕ hides to tray',
            style: Theme.of(context).textTheme.labelSmall),
        const Spacer(),
        TextButton(
          onPressed: () async {
            await Process.run('explorer.exe', [GitService.projectsRoot]);
          },
          child: Text('open folder',
              style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: KColors.textSecondary)),
        ),
      ],
    );
  }
}