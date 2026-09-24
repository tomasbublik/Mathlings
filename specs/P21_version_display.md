# P21 — Verzování a viditelná verze v Main Menu

**Tier:** Haiku 4.5 · **Wave:** 5 · **Deps:** P8a (Main Menu), P15 (project.godot už má `config/version`).

## Scope

Aplikace má v `project.godot` `config/version="1.0.0"`, ale verze není uživateli nikde vidět. Při hlášení bugů to ztěžuje zjištění, kterou build hráč spustil.

1. **Zobrazit verzi v Main Menu.** Pravý dolní roh, malý font (16-20pt), nenápadný s lehkým outlinem (čitelný proti pozadí). Formát: `v1.0.0`.
2. **Zavést konvenci verzování.** Semantic versioning (MAJOR.MINOR.PATCH). Dokumentovat v README.md jak verzi posunout (před release: edit `project.godot` + `export_presets.cfg::version/name` + commit s tagem `vX.Y.Z`).
3. **Volitelně — debug build marker.** Pokud `OS.is_debug_build()`, přidat za verzi `+debug`, např. `v1.0.0+debug`. V release stavbě nic nepřidá.

**Mimo scope:** auto-bumpování verze CI pipelinem; in-app update notifikace.

## Files to create / modify

- `scenes/main_menu/main_menu.tscn` — přidat `Label` v pravém dolním rohu.
- `scenes/main_menu/main_menu.gd` — v `_ready()` načíst verzi přes `ProjectSettings.get_setting("application/config/version")` a aplikovat na Label.
- `README.md` — přidat sekci „Versioning" s návodem.
- `tests/unit/test_main_menu_version.gd` — _volitelné_, jen pokud jde rozumně testovat (extract logiky do `class_name VersionInfo` s helperem `format_for_display(version: String, debug: bool) -> String`).

## Implementace skicní

```gdscript
# scenes/main_menu/main_menu.gd
@onready var _version_label: Label = %VersionLabel

func _ready() -> void:
    ...
    _version_label.text = _format_version()

func _format_version() -> String:
    var v := String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
    var suffix := "+debug" if OS.is_debug_build() else ""
    return "v%s%s" % [v, suffix]
```

Label v `.tscn`:

```
[node name="VersionLabel" type="Label" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 3                      # bottom-right
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -150.0
offset_top = -36.0
offset_right = -16.0
offset_bottom = -8.0
theme_override_colors/font_color = Color(1, 1, 1, 0.7)
theme_override_colors/font_outline_color = Color(0, 0, 0, 0.8)
theme_override_constants/outline_size = 3
theme_override_font_sizes/font_size = 18
text = "v0.0.0"
horizontal_alignment = 2                # right
```

## Versioning konvence (README sekce)

```
## Versioning

This project follows [Semantic Versioning](https://semver.org/).
The single source of truth is `project.godot::application/config/version`.

To release a new version:

1. Bump version in `project.godot` and mirror it in `export_presets.cfg::preset.0.options/version/name`.
2. Bump `version/code` in `export_presets.cfg` by +1 (Android Play Store hard requirement).
3. Commit: `chore: bump version to vX.Y.Z`.
4. Tag: `git tag vX.Y.Z && git push --tags`.
5. Re-export APK/AAB.
```

## Definition of Done

1. V Main Menu je dole vpravo viditelná verze `v1.0.0` (matchuje hodnotu z `project.godot`).
2. V debug buildu (`Editor → Run`) se zobrazí `v1.0.0+debug`. V release exportu jen `v1.0.0`.
3. README obsahuje sekci „Versioning" s návodem.
4. Změna `config/version` na `1.0.1` a re-spuštění → Label se aktualizuje (žádný hardcode v UI).

## Otevřené otázky

- **Umístění Labelu.** Spec navrhuje pravý dolní roh — pokud je v UI překryv s `BottomBar` (profil + nastavení), agent může umístit do levého dolního rohu nebo nad bottom bar. Pravidlo: nikdy nesmí překrývat tlačítko.

## Implementation log

- `scripts/ui/version_info.gd` (`class_name VersionInfo`) má 3 statické funkce: `current_version()` čte ProjectSettings, `format_for_display(version, is_debug)` je pure helper pro testy, `display_string()` je convenience wrapper.
- Konstanty `PROJECT_VERSION_KEY`, `UNKNOWN_VERSION`, `DEBUG_SUFFIX` jsou dokumentované; nikde žádný hardcoded řetězec.
- Main Menu má v `.tscn` nový `VersionLabel` (anchor 3 = bottom-right, 134×18 px, font 18, semitransparent outline). V `_ready` se naplní přes `VersionInfo.display_string()`.
- README.md má novou sekci „Versioning" s release postupem (bump + tag).
- `tests/unit/test_version_info.gd` — 6 testů: release/debug formátování, pre-release tagy, fallback chování + current_version proti reálnému ProjectSettings.
