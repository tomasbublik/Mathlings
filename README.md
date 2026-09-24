# Mathlings

Arkádová matematická hra pro děti (1.-3. třída ZŠ) s adaptivním tutorem v pozadí.
Postavená na **Godot 4.3+**, běží na **Android 10+** (tablet primárně) a **macOS** pro vývoj.

## Rychlý start (macOS dev)

1. **Nainstaluj Godot 4.3+**:
   ```
   brew install --cask godot
   ```
   nebo stáhni z [godotengine.org](https://godotengine.org/download) (Standard edition, GDScript stačí).

2. **Otevři projekt**:
   - Spusť Godot, klikni `Import`, vyber `project.godot` v tomto repu.
   - Nebo z CLI: `open -a Godot project.godot`.

3. **Spusť**: F5 nebo tlačítko ▶ vpravo nahoře. Měla by se objevit placeholder MainMenu scéna.

## Struktura

```
.
├── DESIGN.md          ← autoritativní architektura a kontrakty
├── specs/             ← work packages (Pxx) pro subagenty
│   └── README.md      ← dependency graph + model tier matrix
├── project.godot
├── scenes/            ← .tscn scény
├── scripts/
│   ├── autoload/      ← singletony (registered v project.godot)
│   ├── game/
│   ├── tutor/
│   ├── persistence/
│   └── ui/
├── assets/            ← audio, fonty, obrázky (placeholder nejdřív)
├── addons/            ← godot-sqlite, gut (testing)
└── tests/unit/        ← GUT testy
```

## Vývoj paralelně s více agenty

Projekt je rozdělen do **work packages** (`specs/Pxx_*.md`). Každý WP je nezávislý balík práce navržený tak, aby ho zpracoval jeden subagent v jednom sezení bez nutnosti číst ostatní WP.

**Začni zde:** [`specs/README.md`](specs/README.md) — obsahuje dependency graph, wave ordering a doporučený model tier (Haiku / Sonnet / Opus) pro každý WP.

Doporučený postup prvního sprintu:
1. Wave 1 (P1-P6) paralelně v samostatných sezeních nebo worktree.
2. Wave 2 (P7, P8a/b/c, P9) paralelně po dokončení Wave 1.
3. Wave 3 (P10) serial — spojuje všechno.

## Automated Testing

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
prevent confusing them with release APKs in screenshots.

To release a new version:

1. Bump `application/config/version` in `project.godot`.
2. Mirror the same value in `export_presets.cfg::version/name`.
3. Bump `version/code` in `export_presets.cfg` by **+1** (Play Store hard requirement).
4. Commit: `chore: bump version to vX.Y.Z`.
5. Tag: `git tag vX.Y.Z && git push --tags`.
6. Re-export APK / AAB.

## Android export (P15)

Konfigurace je v `export_presets.cfg` (profil `Android`, package `com.mathlings.app`,
arm64-v8a, min SDK 29, jediná oprávnění: `VIBRATE`, `WAKE_LOCK`). Orientace je zamčena
na `sensor_landscape` v `project.godot`.

### Jednorázový setup (macOS)

```bash
brew install --cask android-commandlinetools
brew install openjdk@17
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

V Godotu: `Editor Settings → Export → Android` — nastav cesty k JDK a Android SDK.
`Editor → Manage Export Templates → Download` pro příslušnou verzi Godotu.

### Debug keystore (jednorázově, ~/.android/debug.keystore)

```bash
keytool -keyalg RSA -genkeypair -alias androiddebugkey \
    -keypass android -keystore ~/.android/debug.keystore \
    -storepass android -dname "CN=Android Debug,O=Android,C=US" \
    -validity 10000
```

### Release keystore (před prvním release buildem)

```bash
keytool -v -genkey -keystore ./release.keystore -alias mathlings \
    -keyalg RSA -validity 10000
```

Cestu k `release.keystore` + heslo nastav v editoru
`Project → Export → Android → Options → Keystore/Release` (neukládá se do Gitu;
patří do `export_credentials.cfg`, který je v `.gitignore`).

### Build

```bash
godot --headless --export-release "Android" build/mathlings.aab
# nebo pro debug APK:
godot --headless --export-debug "Android" build/mathlings.apk
```

## Licence

_(TBD — zvolit před release)_
