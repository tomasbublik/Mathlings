# Mathlings — Design & Architecture

> **Authoritative document.** If anything in `specs/*.md` contradicts this document, DESIGN.md takes precedence and the spec must be corrected. The shared contracts (§7) must not be changed by any subagent without the project owner's approval.

---

## 1. Project goals

- Falling maths problems, 3 answer buttons (1 correct, 2 plausible wrong ones).
- Target audience: Years 1–3 of primary school (ages 6–10), primarily tablets in landscape.
- Platforms: **Android 10+** (API 29+) primarily; **macOS** for development and debugging.
- Offline-first, no account, no ads, no IAP, no cloud telemetry.
- On the outside the app is an arcade game; on the inside it is an adaptive tutor (Elo per skill).
- UI language: **Czech**; code and identifiers: **English**.

## 2. Non-functional requirements

| Category | Requirement |
|---|---|
| Performance | 60 FPS on a mid-range Android tablet (Snapdragon 7xx, 4 GB RAM) |
| Start-up | Cold start < 2 s to the Main Menu |
| APK size | Target < 60 MB (AAB) |
| Offline | Fully functional without an internet connection |
| Storage | All data stored locally in `user://` (SQLite + ConfigFile) |
| Accessibility | Minimum touch target size of 72 dp; WCAG AA contrast for text |
| Security | No network calls, no file access outside `user://` and `res://` |
| Localisation | Structure ready for i18n, launch locale: cs_CZ |
| Parental gate | Settings and statistics hidden behind a simple maths question |

## 3. Tech stack

- **Engine:** Godot **4.3+** (stable).
- **Language:** GDScript (static typing wherever possible).
- **Database:** SQLite via the [`godot-sqlite`](https://github.com/2shady4u/godot-sqlite) addon (single `.gdextension`).
- **Version control:** Git, trunk-based on `main`, feature branches named after the WP ID (`p3-audio-manager`).
- **Tests:** [`GUT`](https://github.com/bitwes/Gut) for unit tests in `tests/unit/`.
- **Build:** Godot export templates, Android via Gradle; macOS via the editor.

## 4. Architecture

```
┌──────────────────────────────────────────────────┐
│ Presentation (Godot scenes, UI nodes, animation) │
│  scenes/main_menu, scenes/game, scenes/settings, │
│  scenes/results, scenes/stats                    │
├──────────────────────────────────────────────────┤
│ Game Logic                                       │
│  GameController, FallingProblemManager,          │
│  AnswerValidator, scripts/game/*                 │
├──────────────────────────────────────────────────┤
│ Adaptive Tutor                                   │
│  SkillModel (Elo), ProblemGenerator,             │
│  DifficultyController, AttemptLogger             │
│  scripts/tutor/*                                 │
├──────────────────────────────────────────────────┤
│ Platform Services (autoloads)                    │
│  SettingsStore, AudioManager, HapticsManager,    │
│  DB, GameState, EventBus                         │
├──────────────────────────────────────────────────┤
│ Persistence                                      │
│  SQLite via godot-sqlite, schema v1              │
│  scripts/persistence/*                           │
└──────────────────────────────────────────────────┘
```

**Key principles:**
1. No UI node may read from or write to the DB directly → always go through a DAO in `scripts/persistence/`.
2. Modules communicate **primarily via `EventBus` signals**; direct calls only where they make sense (e.g. UI → AudioManager.play_sfx).
3. Autoloads are only façades; business logic lives in ordinary classes (better testability).
4. All times are `int` milliseconds (never `float` seconds for persisted data).

## 5. Directory structure

```
mathlings/
├── project.godot
├── icon.svg
├── .gitignore
├── DESIGN.md                ← this document
├── README.md
├── addons/                  ← godot-sqlite (after P2)
├── assets/
│   ├── audio/{sfx,music}/
│   ├── fonts/
│   └── images/{backgrounds,skins,ui,particles}/
├── scenes/
│   ├── main_menu/
│   ├── game/
│   ├── settings/
│   ├── results/
│   ├── stats/
│   └── shared/              ← reusable: buttons, dialogs, parent_gate
├── scripts/
│   ├── autoload/            ← SettingsStore, AudioManager, Haptics, DB, GameState, EventBus
│   ├── game/                ← controllers, validators, falling entity
│   ├── tutor/               ← SkillModel, ProblemGenerator, DifficultyController
│   ├── persistence/         ← schema.sql, DAOs
│   └── ui/                  ← reusable UI helpers
├── tests/unit/              ← GUT
└── specs/                   ← work packages for subagents
```

## 6. Data models

### 6.1 SQLite schema (v1)

```sql
-- profiles: support for several children on one tablet
CREATE TABLE profiles (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    avatar_key TEXT,
    created_at INTEGER NOT NULL    -- unix ms
);

-- skills: skills tracked by Elo rating
-- the key is a stable string: "add_0_20", "sub_0_100", "mul_x7", "div_0_100", ...
CREATE TABLE skills (
    profile_id INTEGER NOT NULL,
    skill_key TEXT NOT NULL,
    rating REAL NOT NULL DEFAULT 1000.0,
    attempts INTEGER NOT NULL DEFAULT 0,
    correct INTEGER NOT NULL DEFAULT 0,
    last_seen_at INTEGER,
    PRIMARY KEY (profile_id, skill_key),
    FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

-- sessions: a single round of the game
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY,
    profile_id INTEGER NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    duration_ms INTEGER,
    score INTEGER NOT NULL DEFAULT 0,
    best_streak INTEGER NOT NULL DEFAULT 0,
    accuracy REAL,                  -- 0.0-1.0
    config_json TEXT NOT NULL,      -- configuration snapshot
    FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

-- attempts: every problem shown
CREATE TABLE attempts (
    id INTEGER PRIMARY KEY,
    session_id INTEGER NOT NULL,
    skill_key TEXT NOT NULL,
    expression TEXT NOT NULL,       -- "7 + 5"
    correct_answer INTEGER NOT NULL,
    choices_json TEXT NOT NULL,     -- "[12, 13, 10]"
    chosen_index INTEGER,           -- NULL if missed
    correct INTEGER NOT NULL,       -- 0/1
    reaction_ms INTEGER,            -- NULL if missed
    shown_at INTEGER NOT NULL,
    resolved_at INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

-- unlocks: unlocked skins, backgrounds, badges
CREATE TABLE unlocks (
    profile_id INTEGER NOT NULL,
    kind TEXT NOT NULL,             -- 'background' | 'skin' | 'badge'
    key TEXT NOT NULL,
    unlocked_at INTEGER NOT NULL,
    PRIMARY KEY (profile_id, kind, key),
    FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

CREATE INDEX idx_attempts_session ON attempts(session_id);
CREATE INDEX idx_attempts_skill ON attempts(skill_key);
CREATE INDEX idx_sessions_profile ON sessions(profile_id, started_at);
```

Schema migrations: a `meta(key TEXT PRIMARY KEY, value TEXT)` table with a `schema_version` row.

### 6.2 Skill keys (canonical)

| Key | Description | Difficulty D (for Elo) |
|---|---|---|
| `add_0_10` | a+b, a,b ∈ [0,10] | 900 |
| `add_0_20` | a+b, sum ≤ 20 | 1000 |
| `add_0_100` | a+b, sum ≤ 100 | 1100 |
| `sub_0_10` | a-b, a,b ∈ [0,10], b≤a | 950 |
| `sub_0_20` | a-b, a ≤ 20, b≤a | 1050 |
| `sub_0_100` | a-b, a ≤ 100, b≤a | 1150 |
| `mul_x2` … `mul_x10` | times table × k | 1000 + (k-2)*30 |
| `div_0_100` | a/b, b ∈ [2,10], divides with no remainder | 1200 |

> **Convention:** keys never change meaning. New difficulty levels are added under a new key, never by modifying an existing one.

### 6.3 Settings (ConfigFile `user://settings.cfg`)

```
[general]
locale = "cs_CZ"
audio_sfx = true
audio_music = true
haptics = true

[round]
duration_s = 120              ; 30/60/120/180/300
speed_preset = "adaptive"     ; slow | normal | fast | adaptive

[skills]
enabled = ["add_0_20","sub_0_20","mul_x2","mul_x5","mul_x10"]

[profile]
active_id = 1
```

## 7. Shared contracts (STABLE API)

No WP may change these types/signals without a coordinated change across all dependants.

### 7.1 `Problem` (structured Dictionary)

```gdscript
# scripts/game/problem.gd (class or typed dict - see P1)
# {
#   "id": int,                    # auto-increment per session
#   "skill_key": String,          # see §6.2
#   "expression": String,         # "7 + 5"
#   "correct_answer": int,        # 12
#   "choices": Array[int],        # [12, 13, 10], always length 3, shuffled
#   "correct_index": int,         # index of the correct answer in choices
#   "difficulty": float,          # D for Elo
# }
```

### 7.2 EventBus signals

See `scripts/autoload/event_bus.gd`. New signals are **added**, never removed (only marked with an `@deprecated` comment).

### 7.3 Autoload API (surface)

- `SettingsStore.get_value(key: String, default) / set_value(key, value) / save()`
- `AudioManager.play_sfx(key: String) / play_music(key, fade_ms) / stop_music(fade_ms)`
- `HapticsManager.pulse(pattern: HapticsManager.Pattern)`
- `DB.open() / close() / execute(sql, params) -> Array`
- `GameState.reset_round()`

### 7.4 Audio SFX keys

| Key | When |
|---|---|
| `correct` | Correct answer |
| `wrong` | Wrong answer |
| `miss` | Problem hit the ground |
| `tick` | Ticking during the last 10 s |
| `round_start` | Round start |
| `round_end` | Round end |
| `combo_up` | Combo increase (3+, 5+, 10+) |
| `unlock` | Badge/skin unlocked |

## 8. Adaptive tutor — algorithm

### 8.1 Elo update

After each attempt (for skill `s` with rating R and a problem with difficulty D):

```
expected = 1 / (1 + 10 ^ ((D - R) / 400))
actual   = 1.0 if correct and reaction ≤ 3000 ms
           0.7 if correct and reaction > 3000 ms
           0.0 if wrong or missed
K = 32 while attempts < 20, then 16
R_new = R + K * (actual - expected)
R_new = clamp(R_new, 600, 1800)
```

### 8.2 Choosing the next skill (ProblemGenerator)

1. Filter the active skills from those enabled in Settings.
2. For each, compute `weight = max(0, 1500 - rating)` (low rating ⇒ higher weight).
3. Normalise into probabilities.
4. With probability **0.15**, inject an **easy** one (highest rating) — prevents frustration.
5. With probability **0.10**, inject **one step harder** — encourages growth.
6. Otherwise, pick according to the weights.

### 8.3 Generating the 3 answers

1 correct + 2 **plausible** wrong answers. Distractors are chosen using these heuristics (depending on the operation):

- Addition: ±1, ±2, digit error (swapping units/tens), correct result ±10.
- Subtraction: swapped operands, ±1, forgotten borrow.
- Times tables: neighbouring multiple (`a*(b±1)`), or `a+b` (a typical mistake).
- Division: neighbouring quotient, `a-b`.

Distractors must not be:
- Equal to the correct answer.
- Negative (for Years 1–2).
- Duplicates of each other.

If the heuristics fail, fall back to `correct ± random(1..5)`.

### 8.4 Adaptive speed

```
base_speed_px_s = 120
streak_mult    = 1.0 + min(streak, 10) * 0.03
rating_mult    = 1.0 + (avg_rating - 1000) / 1000   ; clamp [0.7, 1.6]
speed = base * streak_mult * rating_mult
```

After 3+ mistakes in a row: `speed *= 0.8` until 2 correct answers in a row.

## 9. Game loop (GameController)

```
STATE_MACHINE: IDLE → COUNTDOWN → PLAYING → ENDING → RESULT

IDLE:
  - waits for the start signal from MainMenu

COUNTDOWN (3 s):
  - shows "3, 2, 1, GO!"
  - plays the round_start SFX
  - creates the sessions row, emits round_started

PLAYING:
  - loop: spawn problem → falling animation → tap or miss → log → next
  - update the timer every frame; when ≤ 0 → ENDING
  - max 1 active problem at a time (MVP)

ENDING:
  - stop spawning, let the current one finish falling (or hide it)
  - compute the summary (accuracy, best_streak, final_score)
  - update the sessions row, emit round_ended
  - pair up the skills whose rating moved, check for unlocks

RESULT:
  - transition to scenes/results

PAUSE (orthogonal, COUNTDOWN / PLAYING only):
  - HUD pause chip, Android back, or the app losing focus / going to background
  - controller.pause(): tick / on_answer / on_miss are ignored; the scene sets
    get_tree().paused = true and shows the pause overlay (PROCESS_MODE_ALWAYS)
  - Continue → controller.resume() (reaction-time clock shifted by the pause)

ABORTED (pause menu → "Quit round"):
  - controller.abort_round(): no round_ended, no results, no unlocks,
    no SessionStatsStore record; the sessions row + its attempts are deleted
  - skill ratings from answers already given are kept
  - emits round_aborted (EventBus.round_aborted), scene returns to main menu
```

## 10. UI wireframes (ASCII)

### 10.1 Main Menu

```
┌────────────────────────────────────────────────────┐
│                                                    │
│                 MATHLINGS                          │
│                                                    │
│           ┌──────────────────┐                     │
│           │     PLAY! ▶      │                     │
│           └──────────────────┘                     │
│                                                    │
│           ┌──────────────────┐                     │
│           │  Statistics 📊   │                     │
│           └──────────────────┘                     │
│                                                    │
│  profile: Alex 👦       settings⚙    parent🔒      │
└────────────────────────────────────────────────────┘
```

### 10.2 Game Screen

```
┌────────────────────────────────────────────────────┐
│ 🏆 Score: 120       streak: 🔥x3      ⏱ 1:23       │
│ ═══════════════════════════════════════            │
│                                                    │
│            ╭────────╮                              │
│            │  7+5   │  ← falling down              │
│            ╰────────╯                              │
│                                                    │
│                                                    │
│                                                    │
│                                                    │
│    ┌──────┐    ┌──────┐    ┌──────┐               │
│    │  12  │    │  13  │    │  10  │               │
│    └──────┘    └──────┘    └──────┘               │
└────────────────────────────────────────────────────┘
```

### 10.3 Result

```
┌────────────────────────────────────────────────────┐
│                  Great job! 🎉                     │
│                                                    │
│              Score: 240 ⭐⭐⭐                      │
│              Accuracy: 87 %                        │
│              Longest streak: 12 🔥                 │
│                                                    │
│     You unlocked: Space theme 🚀                   │
│                                                    │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    │
│   │Play again│    │Statistics│    │   Menu   │    │
│   └──────────┘    └──────────┘    └──────────┘    │
└────────────────────────────────────────────────────┘
```

### 10.4 Parent Gate

```
┌────────────────────────────────────────────────────┐
│        Parents only                                │
│                                                    │
│        What is  17 × 8 ?                           │
│                                                    │
│        ┌─────────────┐                             │
│        │             │                             │
│        └─────────────┘                             │
│                                                    │
│             [Confirm]                              │
└────────────────────────────────────────────────────┘
```

## 11. Testing strategy

- **Unit (GUT):** ProblemGenerator (distribution, distractor validity), SkillModel (Elo update, clamp), AnswerValidator, DAOs (integration with in-memory SQLite).
- **Manual smoke test:** After each WP, run Main Menu → Play → finish a round → Result.
- **Target coverage:** ≥ 80 % of `scripts/tutor/` and `scripts/game/` (the rest of the UI is tested manually).

## 12. Build & deployment

- **macOS dev:** Open `project.godot` in the Godot 4.3+ editor.
- **Android export:** Install the export templates, configure the Android SDK and a debug keystore. AAB for release.
- **CI (later):** GitHub Actions workflow `.github/workflows/build.yml` — Android export + unit tests.

## 13. Open questions / to be decided later

- [ ] Visual style — specific art direction (can be a placeholder → final in P12).
- [ ] Music — custom vs. a CC0 pack.
- [ ] Adding timed challenges and tournaments (v2).
- [ ] Support for two children on the same tablet (profiles are ready, UX later).

## 14. Glossary

- **WP** = Work Package (`specs/Pxx_*.md`), a unit of work for a subagent.
- **Skill** = a uniquely named ability tracked by an Elo rating.
- **Distractor** = one of the two wrong answers in the set of three.
- **Streak** = the number of consecutive correct answers in the current round.
- **Combo** = a points multiplier derived from the streak (1× / 1.5× / 2× / 3×).
