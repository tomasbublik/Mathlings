# P3 — Audio Manager

**Tier:** Haiku 4.5 · **Wave:** 1 (paralelní) · **Deps:** P6 (placeholder SFX) může běžet paralelně; AudioManager akceptuje chybějící soubor gracefully.

## Scope

Centrální přehrávač SFX a hudby. Klíče → soubory přes resource mapu. Respektuje `SettingsStore` flagy `audio_sfx`, `audio_music`.

## Files to create / modify

- `scripts/autoload/audio_manager.gd` — **úprava** stubu.
- `scripts/autoload/audio_catalog.gd` — mapa klíč → path (const dict).
- `tests/unit/test_audio_manager.gd` — GUT smoke (fake catalog).

## API (viz DESIGN §7.3 a §7.4)

```gdscript
extends Node

func play_sfx(key: String) -> void
func play_music(key: String, fade_ms: int = 500) -> void
func stop_music(fade_ms: int = 500) -> void
```

## Chování

1. Na startu načti `SettingsStore.get_value("audio_sfx", true)` a `audio_music`.
2. Poslouchej `EventBus.settings_changed` — když změna, re-cache flagy.
3. SFX: 4 dedikované `AudioStreamPlayer` nody v poolu (aby dva zvuky mohly hrát přes sebe).
4. Hudba: 1 dedikovaný `AudioStreamPlayer` s tween fade-in/out přes `fade_ms`.
5. Pokud je flag off → no-op.
6. Pokud key chybí v `audio_catalog.gd` → `push_warning` a no-op (nepoškodit běh).
7. Pokud soubor v `AudioCatalog` neexistuje → `push_warning` a no-op.

## Audio catalog (start)

```gdscript
# scripts/autoload/audio_catalog.gd
class_name AudioCatalog

const SFX := {
    "correct":     "res://assets/audio/sfx/correct.ogg",
    "wrong":       "res://assets/audio/sfx/wrong.ogg",
    "miss":        "res://assets/audio/sfx/miss.ogg",
    "tick":        "res://assets/audio/sfx/tick.ogg",
    "round_start": "res://assets/audio/sfx/round_start.ogg",
    "round_end":   "res://assets/audio/sfx/round_end.ogg",
    "combo_up":    "res://assets/audio/sfx/combo_up.ogg",
    "unlock":      "res://assets/audio/sfx/unlock.ogg",
}

const MUSIC := {
    "menu":   "res://assets/audio/music/menu_loop.ogg",
    "game":   "res://assets/audio/music/game_loop.ogg",
}
```

## Testy

- `play_sfx("correct")` volá `ResourceLoader` (můžeš mock/spy); pokud resource `null`, no throw.
- `play_sfx` s vypnutým flagem → žádný `AudioStreamPlayer.play()`.
- `play_music("menu")` následované `stop_music()` → hlasitost končí 0.

## Definition of Done

Společné + manuálně ověřeno: z `_ready` scény se úspěšně zavolá `AudioManager.play_sfx("correct")` bez chyby i když soubor neexistuje.

## Otevřené otázky

Žádné. Spec byl jasný a úplný.

## Implementation log

**Soubory vytvořeny/upraveny:**
- `scripts/autoload/audio_catalog.gd` (nový) — const dict `SFX` + `MUSIC` dle specifikace
- `scripts/autoload/audio_manager.gd` (rozšíření) — plná implementace z stubu
- `tests/unit/test_audio_manager.gd` (nový) — GUT smoke testy

**Designová rozhodnutí:**
1. **SFX pool**: 4 × AudioStreamPlayer s round-robin indexem (`_sfx_current_index`). Zajistí, že více zvuků může hrát překryvem.
2. **Tween lifecycle**: Při `play_music()` i `stop_music()` se existující tween nejdřív zabije (`_music_tween.kill()`), pak se vytvoří nový. Chrání před race conditions.
3. **Volume hodnoty**: Start-muted (-80 dB) na play_music, fade na 0 dB. Stop fáduje zpět na -80 dB a poté zavolá `.stop()`.
4. **ResourceLoader caching**: `CACHE_MODE_REUSE` udržuje assety v paměti a eliminuje opakované loadování.
5. **Error handling**: Všechny chybějící klíče i failované resource loads → `push_warning` bez výjimky (graceful no-op).
6. **Settings integration**: `_ready()` načte flagy z `SettingsStore`, potom poslouchá `EventBus.settings_changed` signál pro runtime změny.

**Testy (GUT):**
- `test_play_sfx_with_flag_disabled()` — ověří no-op při vypnutém SFX flagu
- `test_play_sfx_unknown_key()` — ověří warning bez chyby
- `test_play_music_unknown_key()` — ověří warning bez chyby
- `test_sfx_pool_round_robin()` — ověří cyklování přes pool
- `test_play_music_with_flag_disabled()` — ověří no-op při vypnuté hudbě
- `test_stop_music_cancels_tween()` — ověří tween cancellation

Implementace splňuje všechny body Definition of Done: static typing, dokumentace `##`, graceful handling chybějících assetů, pooling, fade s tweeny, flags respektování.
