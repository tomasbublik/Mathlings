# P10 — Game Controller (hlavní orchestrace)

**Tier:** Opus 4.7 · **Wave:** 3 (serial) · **Deps:** P1, P2, P3, P4, P5, P7, P9.

## Scope

Orchestrace celého kola hry. State machine `IDLE → COUNTDOWN → PLAYING → ENDING → RESULT`. Spawn problémů, handling inputu (3 tlačítka), timer, skóre, streak/combo, update tutor, přechod na Results.

Zahrnuje **herní scénu** (`scenes/game/game.tscn`) s HUD a 3 tlačítky odpovědí.

## Files to create

- `scenes/game/game.tscn` — hlavní herní scéna.
- `scenes/game/game.gd` — `extends Node2D`, obsahuje GameController logiku nebo ji deleguje na `scripts/game/game_controller.gd`.
- `scripts/game/game_controller.gd` — `class_name GameController extends RefCounted` (preferováno pro testovatelnost).
- `scripts/game/answer_validator.gd` — `class_name AnswerValidator` — tenký pomocník.
- `tests/unit/test_game_controller.gd` — GUT (state machine, bodování, combo).

## Struktura scény `game.tscn`

```
Game (Node2D)
├── Background (TextureRect, téma dle profilu)
├── HUD (CanvasLayer)
│   ├── ScoreLabel
│   ├── StreakLabel
│   ├── TimerLabel
│   └── ComboBadge (hidden when multiplier==1)
├── PlayField (Node2D)        ← sem se spawnují FallingProblem instance
│   └── FloorMarker (Position2D na Y=720-offset)
├── AnswerBar (HBoxContainer dole)
│   ├── AnswerButton1 (BaseButton, TextureRect btn_answer.svg + Label)
│   ├── AnswerButton2
│   └── AnswerButton3
├── CountdownOverlay (CanvasLayer, hidden initially)
└── PauseButton (CanvasLayer)
```

## Veřejné API `GameController`

```gdscript
class_name GameController
extends RefCounted

signal state_changed(new_state: State)
signal spawn_requested(problem: Dictionary, speed_px_s: float)

enum State { IDLE, COUNTDOWN, PLAYING, ENDING, RESULT }

func _init(
    profile_id: int,
    config: Dictionary,           ## snapshot Settings (enabled skills, duration, speed preset)
    db,
    skill_model: SkillModel,
    attempt_logger: AttemptLogger,
    difficulty: DifficultyController,
    rng: RandomNumberGenerator = null
) -> void

func start() -> void              ## IDLE → COUNTDOWN
func tick(delta_s: float) -> void ## scéna volá každý frame; posouvá timer a stav
func on_answer(chosen_index: int, reaction_ms: int) -> void
func on_miss(problem_id: int) -> void
func pause() -> void
func resume() -> void
```

## State machine

```
IDLE
  start() → COUNTDOWN (3s)
        ├─ AudioManager.play_sfx("round_start") ve chvíli t=0
        └─ každou sekundu emit signal → scéna aktualizuje overlay

COUNTDOWN (po 3s) → PLAYING
  - vloží sessions row (začátek), uloží session_id
  - emit round_started(session_id, config)
  - spawn první problem

PLAYING
  - internal timer; když ≤ 0 → ENDING
  - max 1 aktivní problem (MVP)
  - on_answer:
      validate via AnswerValidator
      if correct:
        streak++
        combo = combo_for_streak(streak)
        score += base_points * combo
        AudioManager.play_sfx("correct")
        Haptics.pulse(SUCCESS)
        emit score_changed, streak_changed
        attempt_logger.log(...)
        skill_model.on_attempt(...)
        spawn next
      else:
        streak = 0
        combo = 1
        AudioManager.play_sfx("wrong")
        Haptics.pulse(ERROR)
        attempt_logger.log(...)
        skill_model.on_attempt(...)
        mark current problem to "falling dramatically" + spawn next po 500 ms
  - on_miss:
      streak = 0; combo = 1
      AudioManager.play_sfx("miss")
      Haptics.pulse(MEDIUM)
      attempt_logger.log(... chosen_index=-1, reaction_ms=-1 ...)
      skill_model.on_attempt(..., correct=false, reaction_ms=-1)
      spawn next

ENDING
  - stop spawn
  - ponech aktuální problem dopadnout (nebo maximálně 1.5 s)
  - spočítat accuracy = correct / total, best_streak
  - update sessions row (ended_at, score, best_streak, accuracy)
  - emit round_ended(session_id, summary)
  - zkontroluj unlocks (přes Unlocks helper; pokud P14 není, pošli prázdné pole)
  - GameState.last_result = summary → RESULT

RESULT
  - scéna udělá change_scene_to_file("res://scenes/results/results.tscn")
```

## Bodování

```
base_points = 10
combo_for_streak(streak):
    streak < 3   → 1.0
    streak < 5   → 1.25
    streak < 10  → 1.5
    streak ≥ 10  → 2.0

score_delta = round(base_points * combo)
```

## Spawn rychlost

```
avg_rating = průměr ratingů enabled skills pro aktivní profile
recent_errors = počet chyb v posledních 5 pokusech
speed = DifficultyController.speed_for(avg_rating, streak, recent_errors)
```

## Vstup (3 tlačítka)

Scéna ve svém `_process` nebo `_unhandled_input` deleguje:

```gdscript
func _on_answer_pressed(index: int) -> void:
    var elapsed_ms = Time.get_ticks_msec() - _current_problem_shown_at_ms
    controller.on_answer(index, elapsed_ms)
```

Po stisku rychle disable všechny 3 tlačítka do dalšího spawn (zabránit double-click).

## Testy

- `test_state_machine`: start() → COUNTDOWN; po 3 s → PLAYING; po duration_s → ENDING.
- `test_scoring_combo`: 11 správných → score = 10 + 10 + 12 + 12 + 15 + 15 + 15 + 15 + 15 + 20 + 20.
- `test_wrong_resets_streak`.
- `test_miss_is_wrong`: on_miss vede k `skill_model.on_attempt` s correct=false.
- `test_no_spawn_after_ending`: po přechodu ENDING žádný `spawn_requested` signál.

## Definition of Done

Společné + na macOS v Godotu: klikni Hrát → 3 s countdown → hraje se kolo s padajícími příklady → po duration se objeví Results scéna s reálným skóre. Databáze obsahuje session a attempts. Skill ratings se změnily.

## Otevřené otázky

- `AnswerValidator` implementace je minimální (jen `is_correct(problem, index)`); pokud by budoucí WP chtěl validovat např. typ chyby pro adaptivní distraktory, je to rozšíření.
- Audio/Haptics se při `_db == null` skipují (unit testy běží bez autoloadů). V runtime scéně je DB vždy autoload, takže se efekty přehrávají normálně.

## Implementation log

- `GameController` je `RefCounted` (nikoli `Node`), takže state machine je testovatelný čistě — scéna volá `tick(delta)` v `_process`.
- State machine: IDLE → COUNTDOWN (3 s, 1 Hz tick signály) → PLAYING (timer + spawn) → ENDING (1,5 s grace) → RESULT (scéna přepne scénu).
- Spawn je řízen signálem `spawn_requested(problem, speed)` — scéna instancuje `FallingProblem`, umístí x a volá `setup()`. Rychlost pádu respektuje `speed_preset` ze Settings (slow/normal/fast fix, adaptive použije `DifficultyController`).
- Správná odpověď spawn následujícího příkladu hned; špatná má 0,5 s zpoždění (`_spawn_delay_s`); miss spawn okamžitě.
- Scoring: `BASE_POINTS = 10` × combo `{<3:1.0, <5:1.25, <10:1.5, ≥10:2.0}` = 10,10,13,13,15×5,20,20 (Godotova `round()` → half-away-from-zero, takže 12.5 → 13).
- Tick SFX: 10 posledních sekund, deduplikace přes `_tick_announced_seconds`.
- Audio/Haptics guardováno přes `_db != null` aby testy bez autoloadů nepadaly.
- Summary + `GameState.last_result` vyplněno při vstupu do ENDING; `new_unlocks` je prázdné (P14 je doplní).
- Tests: 9 GUT testů pokrývá state transitions (IDLE → COUNTDOWN → PLAYING → ENDING → RESULT), scoring combo na 11 správných odpovědích, wrong reset streaku, miss jako wrong, žádný spawn po ENDING.
