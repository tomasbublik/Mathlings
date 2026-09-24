# P4 — Haptics Manager

**Tier:** Haiku 4.5 · **Wave:** 1 (paralelní) · **Deps:** žádné.

## Scope

Tenký wrapper nad `Input.vibrate_handheld(duration_ms)` s předdefinovanými pattern presety. Respektuje `SettingsStore.haptics`. No-op na platformě, která nepodporuje vibrace (např. macOS).

## Files to create / modify

- `scripts/autoload/haptics_manager.gd` — **úprava** stubu.

## API (viz DESIGN §7.3)

```gdscript
extends Node

enum Pattern { LIGHT, MEDIUM, HEAVY, SUCCESS, ERROR }

func pulse(pattern: Pattern) -> void
```

## Chování

| Pattern | Platforma Android | Platforma ostatní |
|---|---|---|
| LIGHT | `vibrate_handheld(30)` | no-op |
| MEDIUM | `vibrate_handheld(60)` | no-op |
| HEAVY | `vibrate_handheld(120)` | no-op |
| SUCCESS | `vibrate_handheld(40)` + po 80ms dalších `30` | no-op |
| ERROR | `vibrate_handheld(150)` | no-op |

1. Detekce platformy: `OS.has_feature("mobile")`.
2. Na startu přečti `SettingsStore.get_value("haptics", true)`; poslouchej `EventBus.settings_changed`.
3. Pokud flag off → no-op.
4. Pro SUCCESS použij `get_tree().create_timer(0.08).timeout` a chain druhý pulz.

## Testy

GUT není vyžadován; stačí manuální smoke na zařízení.

## Definition of Done

Společné + manuálně ověřeno: volání `HapticsManager.pulse(HapticsManager.Pattern.SUCCESS)` z libovolné scény nevyhazuje error a vibruje na Androidu.

## Otevřené otázky

_(vyplní agent)_

## Implementation log

- Implementován `HapticsManager` v `scripts/autoload/haptics_manager.gd`.
- Enum `Pattern` se dvěma výstupy: `_vibrate(ms)` volá `Input.vibrate_handheld()`.
- Detekce platformy v `_ready()`: `OS.has_feature("mobile")`.
- SettingsStore cache v `_haptics_enabled` s listem na `EventBus.settings_changed`.
- SUCCESS pattern: 40 ms, await 0.08 s timer, pak 30 ms (seq, ne paralelně).
- No-op na ne-mobile: stav vrací, Input se nevolá.
- Dne 2026-04-24.
