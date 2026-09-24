# P8a — Main Menu scéna

**Tier:** Sonnet 4.6 · **Wave:** 2 · **Deps:** P5 (SettingsStore), P6 (placeholder assets).

## Scope

Úvodní obrazovka aplikace. Tlačítka: HRÁT, Statistiky, Nastavení (přes Parent Gate), výběr profilu.

**Mimo scope:** samotná herní scéna (P10), Settings scéna (P8b), Parent Gate implementace (součástí tohoto WP - je to malý popup).

## Files to create / modify

- `scenes/main_menu/main_menu.tscn` — **nahradit** placeholder.
- `scenes/main_menu/main_menu.gd` — **nahradit** stub.
- `scenes/shared/parent_gate.tscn`
- `scenes/shared/parent_gate.gd` — `class_name ParentGate extends CanvasLayer`.

## Layout (landscape 1280×720, scale pro tablet)

```
┌──── MainMenu (Control, full-rect) ────────┐
│ Background (TextureRect, bg_sky.svg)       │
│ Logo (Label, 96pt, "Mathlings")         │
│ PlayButton (Button, primární 384×96)       │
│ StatsButton (Button, sekundární)           │
│ HBoxContainer na dně:                      │
│   ProfileBadge │ SettingsButton │          │
└────────────────────────────────────────────┘
```

## Chování

1. Po kliknutí `PlayButton` → `get_tree().change_scene_to_file("res://scenes/game/game.tscn")`.
   - Pokud `scenes/game/game.tscn` neexistuje (P10 hotov ještě není), zobraz toast `"Brzy!"` a nic neměň.
2. `StatsButton` → `scenes/stats/stats.tscn` (když neexistuje, toast).
3. `SettingsButton` → otevře Parent Gate → při úspěchu `scenes/settings/settings.tscn`.
4. `ProfileBadge` zobrazuje `SettingsStore.get_value("profile/active_id")` + jméno z DB (pokud je DB dostupné); pokud není, fallback "Hráč 1".
5. Animace na startu: logo z horního okraje padá (tween 0.6 s bounce), tlačítka fade-in stagger 100 ms.
6. Hudba: `AudioManager.play_music("menu")` v `_ready`.

## Parent Gate

1. `CanvasLayer` overlay, semitransparentní dim 60 %.
2. Zobrazí náhodnou otázku typu "a × b" kde a,b ∈ [11, 19] (pro 8-letého těžké ale pro dospělého snadné).
3. LineEdit + Potvrdit + Zrušit.
4. Signál `passed()` při správné, `cancelled()` jinak.

```gdscript
class_name ParentGate
extends CanvasLayer

signal passed
signal cancelled

static func open(parent: Node) -> ParentGate    ## instancuje a přidá
```

## Testy

Manuální smoke - hlavní cesta menu → parent gate → zadání správné odpovědi → přejde na Settings (i když Settings je ještě stub, tak jen v konzoli bude "Brzy!" toast, pokud scene chybí).

## Definition of Done

Společné + aplikace po spuštění zobrazí menu, hudba hraje, kliknutí na tlačítka dělá správný next step nebo toast.

## Otevřené otázky

_(vyplní agent)_

## Implementation log

- Menu scéna nahradila placeholder; pozadí = `bg_sky.svg`, logo/tlačítka animovány tween + stagger.
- ParentGate je samostatná scéna v `scenes/shared/parent_gate.tscn` (CanvasLayer overlay s PanelContainer), instancovaná přes `ParentGate.open(parent)`.
- Pokud `game.tscn` / `stats.tscn` / `settings.tscn` ještě neexistují, tlačítka zobrazí toast "Brzy!" přes `_show_toast()`.
- Profil se čte ze `SettingsStore.profile/active_id` + `ProfilesDao`; fallback na "Hráč 1" když DB není dostupná.
