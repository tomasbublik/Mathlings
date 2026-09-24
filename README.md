# Mathlings

An arcade maths game for children (Years 1–3 of primary school) with an adaptive tutor running behind the scenes.
Built with **Godot 4.3+**, runs on **Android 10+** (primarily tablets) and **macOS** for development.

## Quick start (macOS development)

1. **Install Godot 4.3+**:
   ```
   brew install --cask godot
   ```
   or download it from [godotengine.org](https://godotengine.org/download) (the Standard edition is enough — GDScript only).

2. **Open the project**:
   - Launch Godot, click `Import` and select `project.godot` in this repository.
   - Or from the CLI: `open -a Godot project.godot`.

3. **Run**: press F5 or the ▶ button in the top-right corner. The MainMenu scene should appear.

## Structure

```
.
├── DESIGN.md          ← authoritative architecture and contracts
├── specs/             ← work packages (Pxx) for subagents
│   └── README.md      ← dependency graph + model tier matrix
├── project.godot
├── scenes/            ← .tscn scenes
├── scripts/
│   ├── autoload/      ← singletons (registered in project.godot)
│   ├── game/
│   ├── tutor/
│   ├── persistence/
│   └── ui/
├── assets/            ← audio, fonts, images
├── addons/            ← godot-sqlite, gut (testing)
└── tests/unit/        ← GUT tests
```

## Parallel development with multiple agents

The project is split into **work packages** (`specs/Pxx_*.md`). Each WP is a self-contained unit of work designed to be completed by a single subagent in a single session, without needing to read the other WPs.

**Start here:** [`specs/README.md`](specs/README.md) — contains the dependency graph, wave ordering and the recommended model tier (Haiku / Sonnet / Opus) for each WP.

Recommended approach for the first sprint:
1. Wave 1 (P1–P6) in parallel, in separate sessions or worktrees.
2. Wave 2 (P7, P8a/b/c, P9) in parallel once Wave 1 is finished.
3. Wave 3 (P10) serially — ties everything together.

## Automated testing

The project ships with a two-layer validation loop. Run it after every change — no Android deploy required:

```bash
./validate.sh
```

Exits non-zero if either layer fails. Screenshots land in `.validation/screenshots/` (gitignored).

### Layer 1 — GUT unit tests (headless, ~10 s)

Logic tests live in `tests/unit/` and use [GUT v9.6.0](https://github.com/bitwes/Gut). No window, no GPU.

```bash
godot --headless --path . res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit -ginclude_subdirs -gexit -glog=1
```

Or from the Godot editor: **GUT panel → Run All**.

### Layer 2 — UI screenshots (portrait + landscape)

Godot boots at two resolutions, captures the main navigation screens, then quits:

```
.validation/screenshots/
  main_menu_landscape_1280x720.png     main_menu_portrait_720x1280.png
  settings_landscape_1280x720.png      settings_portrait_720x1280.png
  profile_picker_landscape_1280x720.png  profile_picker_portrait_720x1280.png
```

To add scenes to the tour, edit `SCENES_TO_VISIT` in `scripts/autoload/validation_manager.gd`.

> **How it works:** `ValidationManager` is a no-op autoload — it only activates when the `--validate-ui`
> CLI argument is present and never runs on Android. Zero overhead in normal gameplay.

## Versioning

The project follows [Semantic Versioning](https://semver.org/) (MAJOR.MINOR.PATCH).
Single source of truth: `project.godot::application/config/version`.
The Main Menu reads it at runtime (see `scripts/ui/version_info.gd`) and
shows `vX.Y.Z` in the bottom-right corner. Debug builds append `+debug` to
avoid confusing them with release APKs in screenshots.

To release a new version:

1. Bump `application/config/version` in `project.godot`.
2. Mirror the same value in `export_presets.cfg::version/name`.
3. Bump `version/code` in `export_presets.cfg` by **+1** (a hard Play Store requirement).
4. Commit: `chore: bump version to vX.Y.Z`.
5. Tag: `git tag vX.Y.Z && git push --tags`.
6. Re-export the APK / AAB.

## Android export (P15)

The configuration lives in `export_presets.cfg` (`Android` profile, package `com.mathlings.app`,
arm64-v8a, min SDK 29, only permissions: `VIBRATE`, `WAKE_LOCK`). Orientation is locked
to `sensor_landscape` in `project.godot`.

### One-off setup (macOS)

```bash
brew install --cask android-commandlinetools
brew install openjdk@17
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

In Godot: `Editor Settings → Export → Android` — set the paths to the JDK and Android SDK.
`Editor → Manage Export Templates → Download` for the matching Godot version.

### Debug keystore (one-off, ~/.android/debug.keystore)

```bash
keytool -keyalg RSA -genkeypair -alias androiddebugkey \
    -keypass android -keystore ~/.android/debug.keystore \
    -storepass android -dname "CN=Android Debug,O=Android,C=US" \
    -validity 10000
```

### Release keystore (before the first release build)

```bash
keytool -v -genkey -keystore ./release.keystore -alias mathlings \
    -keyalg RSA -validity 10000
```

Set the path to `release.keystore` and its password in the editor under
`Project → Export → Android → Options → Keystore/Release` (not stored in Git;
it belongs in `export_credentials.cfg`, which is in `.gitignore`).

### Build

```bash
godot --headless --export-release "Android" build/mathlings.aab
# or, for a debug APK:
godot --headless --export-debug "Android" build/mathlings.apk
```

## Licence

_(TBD — to be chosen before release)_
