# Kuiklon

Paste a GitHub repo link, clone it to `C:\IdeaProjects` in one click — plus quick pull / push for repos already there.

Kuiklon is a small Windows desktop utility built with Flutter. It wraps the git commands you repeat all day so they are one keystroke away.

## Features

- **One-click clone** — paste a GitHub URL (including deep links like `/tree/main` or `/blob/...`) and press `clone` or `Enter`.
- **Auto sync** — if the repo already exists in `C:\IdeaProjects`, the same action pulls and then pushes your local commits if there are any.
- **Manual pull / push** — buttons appear whenever a detected repo already exists locally.
- **Live console output** — git output streams into the console; `Esc` or the `cancel` button stops a running operation.
- **Close to tray** — closing the window hides it to the system tray; left-click restores, right-click offers Show / Open `C:\IdeaProjects` / Quit.
- **Open folders** — jump straight to the repo folder (or the projects root) from the footer or tray.

## Requirements

- Windows 10 or newer
- `git` available on `PATH` (Kuiklon shells out to the installed git)
- Flutter SDK with Windows desktop support enabled (for building from source)

## Build and run

```powershell
flutter pub get
flutter run -d windows          # development
flutter build windows --release # production build at build\windows\x64\runner\Release\kuiklon.exe
```

## Tests

```powershell
flutter analyze
flutter test
```

Unit tests cover repo-name parsing (including deep links and unsafe-name rejection) and exercise real clone/pull/push round trips against local bare-repo fixtures in a temp directory — nothing touches your `C:\IdeaProjects`.

## How it works

- Repos are cloned into `C:\IdeaProjects\<repo-name>` (created automatically if missing).
- The repo name is derived from the URL (`github.com/<user>/<repo>`); names are validated to a safe single path segment before any folder operation.
- Git runs with `GIT_TERMINAL_PROMPT=0` so private repos fail fast with a clear error instead of hanging on a credential prompt. Authenticate via your usual git credential helper.

## Dev notes

- `tools/make_logo.ps1` regenerates the bundled logo/tray icon assets.
- Fonts (Space Grotesk, JetBrains Mono) and icons are bundled in `assets/`.