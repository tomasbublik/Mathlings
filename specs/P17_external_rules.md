# P17 — Externalizovaná pravidla skóre + obrazovka „Pravidla"

**Tier:** Sonnet 4.6 · **Wave:** 5 · **Deps:** P10 (GameController), P8a (Main Menu).

## Scope

Pravidla bodování (combo tiery, base points, případné bonusy) se aktuálně píšou jako konstanty v `scripts/game/game_controller.gd`. Cíl:

1. **Externalizovat do JSON souboru** (`assets/rules/scoring_rules.json`). GameController při startu načte hodnoty místo použití constant.
2. **Přidat „Pravidla" obrazovku.** Nové tlačítko v Main Menu pod „Statistiky" otevře `scenes/rules/rules.tscn` se scrollovatelným textem, který popisuje aktuálně aktivní pravidla **lidsky** (např. „Série 3-4 → násobič 1.25 = 13 bodů za odpověď"). Text se generuje runtime z dat JSONu, takže po editaci JSON se automaticky aktualizuje.

**Mimo scope:** Editor pravidel v hře (jen read-only zobrazení); validace JSON proti schema.

## Files to create / modify

- `assets/rules/scoring_rules.json` — defaultní pravidla (kopie současných hodnot z GameController).
- `scripts/game/scoring_rules.gd` — `class_name ScoringRules` — loader + validator + human-readable formatter.
- `scenes/rules/rules.tscn` + `.gd` — UI scéna.
- `scripts/game/game_controller.gd` — **upravit** `_init` aby si pravidla načetl přes `ScoringRules.load_default()` místo constant (`COMBO_TIERS`, `BASE_POINTS`).
- `scenes/main_menu/main_menu.gd/.tscn` — přidat tlačítko „Pravidla" pod „Statistiky".
- `tests/unit/test_scoring_rules.gd` — round-trip + validace + formatter test.

## JSON schema

```json
{
  "version": 1,
  "base_points": 10,
  "combo_tiers": [
    {"min_streak": 3,  "multiplier": 1.25},
    {"min_streak": 5,  "multiplier": 1.5},
    {"min_streak": 10, "multiplier": 2.0}
  ],
  "wrong_answer_penalty": 0,
  "miss_penalty": 0,
  "combo_sound_streaks": [3, 5, 10]
}
```

`version: 1` — pokud se objeví v budoucnu breaking change, loader fallne na defaulty s `push_warning`.

## Veřejné API `ScoringRules`

```gdscript
class_name ScoringRules

const DEFAULT_PATH: String = "res://assets/rules/scoring_rules.json"

var version: int
var base_points: int
var combo_tiers: Array          ## seřazeno podle min_streak vzestupně
var wrong_answer_penalty: int
var miss_penalty: int
var combo_sound_streaks: Array[int]

static func load_default() -> ScoringRules           ## vrací validní instanci; při chybě fallback na in-code defaulty
static func load_from(path: String) -> ScoringRules

func combo_for_streak(streak: int) -> float          ## stejná semantika jako stávající GameController._combo_for_streak
func points_for_correct(streak: int) -> int
func to_human_readable_text() -> String              ## formátovaný blok dle příkladu v zadání (česky)
```

## `to_human_readable_text()` výstup (vzor)

```
Skóre se počítá podle pravidel verze 1.

Základ je {base_points} bodů za správnou odpověď. Za chybnou odpověď ani za propadlý
příklad se body neodečítají, ale vynuluje se série a kombo.

Kombo podle série správných odpovědí:
  • Série 1–2: násobič 1.0 → +10 bodů
  • Série 3–4: násobič 1.25 → +13 bodů (round(12.5) = 13)
  • Série 5–9: násobič 1.5  → +15 bodů
  • Série 10+: násobič 2.0  → +20 bodů

Příklad: 11 správných odpovědí v řadě = {sum} bodů.

Chybná odpověď nebo miss: pokus se započte do statistik, body se nepřičtou,
série se vynuluje, kombo se vrátí na 1.0.
```

Vše hodnoty injektovány z aktuálních pravidel — žádný hardcode v textu.

## GameController integrace

```gdscript
# Místo const COMBO_TIERS / BASE_POINTS:
var _rules: ScoringRules
func _init(...):
    ...
    _rules = ScoringRules.load_default()

func _apply_correct() -> void:
    ...
    var delta: int = _rules.points_for_correct(_streak)
    ...
```

Konstantní `BASE_POINTS = 10` zůstane, ale jen jako **fallback default** uvnitř `ScoringRules` (DRY: jediný zdroj pravdy = JSON, in-code default je záchranná síť).

## Rules scéna

- Layout: pozadí (theme-aware), `ScrollContainer` → `Label` s `bbcode_enabled = true` (nebo prosté `RichTextLabel` pro lepší typografii), tlačítko „← Zpět" dole.
- Text se získá voláním `ScoringRules.load_default().to_human_readable_text()` v `_ready`.
- Scéna je read-only.

## Testy

- `test_load_default_succeeds` + parsování všech polí.
- `test_load_invalid_path_returns_safe_defaults`.
- `test_load_unknown_version_returns_safe_defaults_with_warning`.
- `test_combo_for_streak_matches_existing_game_controller_behavior` (pin proti stávajícím combo testům).
- `test_points_for_correct_eleven_streak_totals_161` — ekvivalence s `test_scoring_combo_eleven_correct` v `test_game_controller.gd`.
- `test_to_human_readable_includes_all_tier_lines`.

## Definition of Done

1. `scoring_rules.json` existuje s aktuálními hodnotami.
2. GameController nepoužívá `COMBO_TIERS` ani `BASE_POINTS` jako primární zdroj — čte `ScoringRules`.
3. Existující game_controller testy procházejí beze změn (= stejné chování).
4. Tlačítko „Pravidla" v Main Menu otevře scrollovatelnou scénu se správným textem.
5. Editace `scoring_rules.json` (např. změna `base_points` na 20) bez rekompilace → po next round se používá nová hodnota a Pravidla scéna ukazuje aktualizovaný text.
6. `tests/unit/test_scoring_rules.gd` všechny průchozí.

## Otevřené otázky

_(vyplní agent)_

## Implementation log

- `assets/rules/scoring_rules.json` (schema v1) drží aktuální combo tiery a base points; fallback hodnoty jsou v `ScoringRules.DEFAULT_*` constants.
- `scripts/game/scoring_rules.gd` (`class_name ScoringRules`) má `load_default()` / `load_from(path)` (nikdy null, fallback na safety-net), `combo_for_streak`, `points_for_correct`, `to_human_readable_text` a interní normalizéry tierů (sort + filter na malformed entries).
- `GameController._init` má nový volitelný `rules: ScoringRules` parametr (default `null` → `load_default()`); `_apply_correct` a related metody čtou z `_rules` místo konstant. Konstanta `BASE_POINTS` zůstává jako veřejný alias pro UI floating text.
- Hardcoded `_combo_for_streak` z `game_controller.gd` zmizela.
- `scenes/rules/rules.tscn/.gd` — read-only scrollovatelná scéna, pozadí dle aktuálního motivu, body text generován runtime. Tlačítko `RulesButton` v Main Menu otevírá scénu **bez Parent Gate** (read-only, child-safe).
- Testy v `tests/unit/test_scoring_rules.gd` (10 testů): default load, missing/malformed/future-schema fallback, combo thresholds, eleven-streak total = 161 (= existing GameController test pin), human-readable text obsahuje očekávané řádky, custom synthetic rules mění combo křivku.
