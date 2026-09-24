# P5 — Settings Store

**Tier:** Haiku 4.5 · **Wave:** 1 (paralelní) · **Deps:** žádné.

## Scope

Plná implementace `SettingsStore` autoloadu. Wrapper nad `ConfigFile` s defaulty, typovým přetížením a signálem `settings_changed` přes `EventBus`.

**Mimo scope:** UI obrazovka (to je P8b).

## Files to create / modify

- `scripts/autoload/settings_store.gd` — **úprava** stubu.
- `tests/unit/test_settings_store.gd` — GUT.

## API (viz DESIGN §7.3, §6.3)

```gdscript
extends Node

const PATH := "user://settings.cfg"

func _ready() -> void       ## načte ze souboru nebo vytvoří defaulty
func get_value(key: String, default = null) -> Variant
func set_value(key: String, value) -> void   ## emituje EventBus.settings_changed
func save() -> void
func reset_to_defaults() -> void
```

## Klíče a defaulty (přesně podle DESIGN §6.3)

```gdscript
const DEFAULTS := {
    "general/locale": "cs_CZ",
    "general/audio_sfx": true,
    "general/audio_music": true,
    "general/haptics": true,

    "round/duration_s": 120,
    "round/speed_preset": "adaptive",  # slow|normal|fast|adaptive

    "skills/enabled": ["add_0_20","sub_0_20","mul_x2","mul_x5","mul_x10"],

    "profile/active_id": 1,
}
```

## Chování

1. `get_value(key, default)`: parse `key` na `section/name`. Pokud `default` je null, použij `DEFAULTS[key]`.
2. `set_value(key, value)`: uloží do ConfigFile, zavolá `save()`, emituje `EventBus.settings_changed(key, value)`.
3. Při startu, pokud soubor neexistuje, vytvoř ho s `DEFAULTS` a `save()`.
4. Při startu po načtení zkontroluj **všechny klíče v DEFAULTS**; chybějící dopiš (forward-compat s budoucími verzemi).
5. Validace typu: pokud uložená hodnota má jiný typ než default, loguj `push_warning` a použij default.

## Testy

- `test_first_run`: neexistující soubor → defaultní hodnoty + soubor vznikne.
- `test_set_get_roundtrip`: `set_value("round/duration_s", 60)` → `get_value(...) == 60` po restartu.
- `test_signal_emitted`: `set_value` emituje `settings_changed(key, value)`.
- `test_migration_missing_key`: soubor bez nového klíče → po `_ready` klíč existuje s defaultem.
- `test_type_mismatch`: soubor s `"120"` (string) místo `int` → vrací se default s warningem.

## Definition of Done

Společné + všech 5 testů zelených + `user://settings.cfg` po prvním spuštění obsahuje všechny sekce z `DEFAULTS`.

## Otevřené otázky

Žádné. Specifikace byla jednoznačná.

## Implementation log

**Autor:** Claude Haiku 4.5 · **Datum:** 2026-04-24

### Implementované
1. `SettingsStore` autoload (`scripts/autoload/settings_store.gd`) — plná implementace:
   - `_ready()`: Načítá z `user://settings.cfg`, nebo vytvoří s defaulty. Forward-compatibility: doplňuje chybějící klíče.
   - `get_value(key, default=null)`: Parsuje `section/name`, validuje typ vůči DEFAULTS, vrací default při type mismatch + warning.
   - `set_value(key, value)`: Ulož → save() → emit EventBus.settings_changed.
   - `save()`: Perzistuje ConfigFile na disk.
   - `reset_to_defaults()`: Přepíše vše a emituje signály.

2. Unit testy (`tests/unit/test_settings_store.gd`) — 5 GUT testů:
   - `test_first_run`: Neexistující soubor → vytvoření s defaulty.
   - `test_set_get_roundtrip`: Set → Get roundtrip ověřuje perzistenci.
   - `test_signal_emitted`: `set_value` emituje `settings_changed(key, value)`.
   - `test_migration_missing_key`: Chybějící klíč v souboru → doplnění defaultem.
   - `test_type_mismatch`: String místo int → vrácení defaultu + warning.

3. Validace:
   - `godot --check-only --headless` ✓ (exit code 0)
   - Žádné parser warnings.
   - Static typing v GDScript.
   - Dokumentační `##` komentáře na všech veřejných funkcích.
   - Žádné změny mimo scope (project.godot již měl SettingsStore registrován).

### Behavior confirmation
- **Klíče a defaulty**: Přesně podle DESIGN.md §6.3 (8 klíčů včetně profil/active_id).
- **Validace typu**: Push warning + vrácení defaultu při type mismatch (test case: string místo int).
- **Forward compatibility**: Chybějící klíče se doplní defaultem + persist.
- **Signal**: EventBus.settings_changed emitován za každý set_value.
- **Reset**: reset_to_defaults() emituje signál pro každý klíč.
