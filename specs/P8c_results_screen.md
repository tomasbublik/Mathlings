# P8c — Results scéna

**Tier:** Sonnet 4.6 · **Wave:** 2 · **Deps:** P2 (DAO pro read).

## Scope

Obrazovka po skončení kola. Ukáže skóre, přesnost, nejdelší sérii, případně odemčené odznaky. Nabídne "Hrát znovu / Statistiky / Menu".

**Mimo scope:** výpočet toho, co se odemklo (to je logika v P14); tahle scéna jen zobrazuje, co jí `GameState` nebo argumenty předají.

## Files to create

- `scenes/results/results.tscn`
- `scenes/results/results.gd`

## Vstup scény

Scénu otevírá `GameController` (P10) přes `change_scene_to_file` + sdílený autoload `GameState` nebo volně připojený Dictionary. Smluvený vstupní payload:

```gdscript
# GameState.last_result: Dictionary
# {
#   "session_id": int,
#   "score": int,
#   "accuracy": float,           # 0.0 - 1.0
#   "best_streak": int,
#   "total_attempts": int,
#   "correct_attempts": int,
#   "new_unlocks": Array[Dictionary],  # [{"kind":"background", "key":"bg_space", "label":"Vesmír"}]
# }
```

Rozšiř `scripts/autoload/game_state.gd` o `var last_result: Dictionary = {}`.

## Chování

1. `_ready`: přečti `GameState.last_result`; pokud prázdný (např. agent scénu otevře přímo), zobraz placeholder data a varování.
2. Animace: skóre se odpočítává (0 → score) za ~1 s (tween + tick sound).
3. Hvězdičky: 1/2/3 podle accuracy (`< 0.6 / 0.6-0.84 / ≥ 0.85`). Stagger spawn, 150ms odstup.
4. `AudioManager.play_sfx("round_end")` jednou v `_ready`.
5. Každý `new_unlock` zobraz jako kartu s `label` + `AudioManager.play_sfx("unlock")`, stagger 400 ms.
6. Tlačítka:
   - "Hrát znovu" → `scenes/game/game.tscn`.
   - "Statistiky" → `scenes/stats/stats.tscn` (pokud neexistuje, toast).
   - "Menu" → `scenes/main_menu/main_menu.tscn`.

## Testy

Manuální - z nějaké test scény vyplň `GameState.last_result` a otevři Results.

## Definition of Done

Společné + při spuštění přímo (bez `last_result`) scéna nehavaruje a zobrazí placeholder hlášku.

## Otevřené otázky

_(vyplní agent)_

## Implementation log

- `GameState.last_result` (Dictionary) přidáno jako dokumentované pole.
- Score se tweenem odpočítává z 0 na cílovou hodnotu; 10 tick SFX je naplánováno paralelně přes intervaly.
- Hvězdičky se objevují stagger 150 ms dle `_stars_for_accuracy()` (<0.6 / 0.6–0.85 / ≥0.85 = 1/2/3).
- Pokud `GameState.last_result.is_empty()`, scéna zobrazí `PlaceholderNotice` a nepadá (otevřitelná samostatně v editoru).
