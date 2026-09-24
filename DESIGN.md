# Mathlings — Design & Architecture

> **Autoritativní dokument.** Pokud cokoli ve `specs/*.md` odporuje tomuto dokumentu, platí DESIGN.md a spec je třeba opravit. Sdílené kontrakty (§7) nesmí měnit žádný subagent bez souhlasu zadavatele.

---

## 1. Cíle projektu

- Padající matematické příklady, 3 tlačítka s odpověďmi (1 správná, 2 plausibilní špatné).
- Cílová skupina: 1.-3. třída ZŠ (6-10 let), primárně tablet na šířku.
- Platformy: **Android 10+** (API 29+) primárně; **macOS** pro vývoj a ladění.
- Offline-first, žádný účet, žádná reklama, žádné IAP, žádná telemetrie do cloudu.
- Aplikace je navenek arkádová hra, uvnitř adaptivní tutor (Elo per dovednost).
- Jazyk UI: **čeština**; kód a identifikátory: **angličtina**.

## 2. Non-functional requirements

| Kategorie | Požadavek |
|---|---|
| Výkon | 60 FPS na střední třídě Android tabletu (Snapdragon 7xx, 4 GB RAM) |
| Start-up | Cold start < 2 s do Main Menu |
| Velikost APK | Cíl < 60 MB (AAB) |
| Offline | Plně funkční bez internetu |
| Ukládání | Veškerá data lokálně, `user://` (SQLite + ConfigFile) |
| Přístupnost | Min. velikost dotykového tlačítka 72 dp; kontrast WCAG AA na textech |
| Bezpečnost | Žádné síťové volání, žádné čtení souborů mimo `user://` a `res://` |
| Lokalizace | Struktura připravena na i18n, launch: cs_CZ |
| Rodičovská brána | Nastavení a statistiky skryté za jednoduchou matematickou otázkou |

## 3. Tech stack

- **Engine:** Godot **4.3+** (stable).
- **Jazyk:** GDScript (static typing vždy, kde to jde).
- **Databáze:** SQLite přes addon [`godot-sqlite`](https://github.com/2shady4u/godot-sqlite) (single `.gdextension`).
- **Verzování:** Git, trunk-based na `main`, feature branches dle WP ID (`p3-audio-manager`).
- **Testy:** [`GUT`](https://github.com/bitwes/Gut) pro unit testy v `tests/unit/`.
- **Build:** Export template Godot, Android via gradle; macOS přes editor.

## 4. Architektura

```
┌──────────────────────────────────────────────────┐
│ Presentation (Godot scény, UI nody, animace)     │
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
│  SQLite via godot-sqlite, schema v 1             │
│  scripts/persistence/*                           │
└──────────────────────────────────────────────────┘
```

**Klíčové principy:**
1. Žádný UI nod nesmí číst/psát do DB přímo → vždy přes DAO v `scripts/persistence/`.
2. Komunikace mezi moduly **primárně přes `EventBus` signály**; přímé volání jen když dává smysl (např. UI → AudioManager.play_sfx).
3. Autoloady jsou jen fasády; business logika v normálních třídách (lepší testovatelnost).
4. Veškerý čas v `int` milisekundách (nikdy `float` sekundách pro persistentní data).

## 5. Adresářová struktura

```
mathlings/
├── project.godot
├── icon.svg
├── .gitignore
├── DESIGN.md                ← tento dokument
├── README.md
├── addons/                  ← godot-sqlite (po P2)
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
└── specs/                   ← work packages pro subagenty
```

## 6. Datové modely

### 6.1 SQLite schema (v1)

```sql
-- profiles: podpora více dětí na jednom tabletu
CREATE TABLE profiles (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    avatar_key TEXT,
    created_at INTEGER NOT NULL    -- unix ms
);

-- skills: dovednosti sledované Elo ratingem
-- klic je stabilní string: "add_0_20", "sub_0_100", "mul_x7", "div_0_100", ...
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

-- sessions: jedno kolo hry
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY,
    profile_id INTEGER NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    duration_ms INTEGER,
    score INTEGER NOT NULL DEFAULT 0,
    best_streak INTEGER NOT NULL DEFAULT 0,
    accuracy REAL,                  -- 0.0-1.0
    config_json TEXT NOT NULL,      -- snapshot konfigurace
    FOREIGN KEY (profile_id) REFERENCES profiles(id)
);

-- attempts: každý zobrazený příklad
CREATE TABLE attempts (
    id INTEGER PRIMARY KEY,
    session_id INTEGER NOT NULL,
    skill_key TEXT NOT NULL,
    expression TEXT NOT NULL,       -- "7 + 5"
    correct_answer INTEGER NOT NULL,
    choices_json TEXT NOT NULL,     -- "[12, 13, 10]"
    chosen_index INTEGER,           -- NULL pokud minul
    correct INTEGER NOT NULL,       -- 0/1
    reaction_ms INTEGER,            -- NULL pokud minul
    shown_at INTEGER NOT NULL,
    resolved_at INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

-- unlocks: odemčené skiny, pozadí, odznaky
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

Schema migrace: tabulka `meta(key TEXT PRIMARY KEY, value TEXT)` s řádkem `schema_version`.

### 6.2 Skill keys (kanonicky)

| Key | Popis | Obtížnost D (pro Elo) |
|---|---|---|
| `add_0_10` | a+b, a,b ∈ [0,10] | 900 |
| `add_0_20` | a+b, součet ≤ 20 | 1000 |
| `add_0_100` | a+b, součet ≤ 100 | 1100 |
| `sub_0_10` | a-b, a,b ∈ [0,10], b≤a | 950 |
| `sub_0_20` | a-b, a ≤ 20, b≤a | 1050 |
| `sub_0_100` | a-b, a ≤ 100, b≤a | 1150 |
| `mul_x2` … `mul_x10` | násobení tabulkou × k | 1000 + (k-2)*30 |
| `div_0_100` | a/b, b ∈ [2,10], dělí beze zbytku | 1200 |

> **Konvence:** klíče nemění významy. Nové obtížnosti se přidávají novým klíčem, ne úpravou existujícího.

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

## 7. Sdílené kontrakty (STABILNÍ API)

Tyto typy/signály nesmí žádný WP měnit bez sjednocené změny všech závislostí.

### 7.1 `Problem` (strukturovaný Dictionary)

```gdscript
# scripts/game/problem.gd (třída nebo typed dict - viz P1)
# {
#   "id": int,                    # autoinkrement per session
#   "skill_key": String,          # viz §6.2
#   "expression": String,         # "7 + 5"
#   "correct_answer": int,        # 12
#   "choices": Array[int],        # [12, 13, 10], délka vždy 3, shuffled
#   "correct_index": int,         # index správné v choices
#   "difficulty": float,          # D pro Elo
# }
```

### 7.2 EventBus signály

Viz `scripts/autoload/event_bus.gd`. Nové signály se **přidávají**, nikdy neodstraňují (jen `@deprecated` komentář).

### 7.3 Autoload API (povrch)

- `SettingsStore.get_value(key: String, default) / set_value(key, value) / save()`
- `AudioManager.play_sfx(key: String) / play_music(key, fade_ms) / stop_music(fade_ms)`
- `HapticsManager.pulse(pattern: HapticsManager.Pattern)`
- `DB.open() / close() / execute(sql, params) -> Array`
- `GameState.reset_round()`

### 7.4 Audio SFX klíče

| Key | Když |
|---|---|
| `correct` | Správná odpověď |
| `wrong` | Špatná odpověď |
| `miss` | Příklad dopadl na zem |
| `tick` | Tikání v posledních 10 s |
| `round_start` | Start kola |
| `round_end` | Konec kola |
| `combo_up` | Zvýšení comba (3+, 5+, 10+) |
| `unlock` | Odemčení odznaku/skinu |

## 8. Adaptivní tutor - algoritmus

### 8.1 Elo update

Po každém pokusu (pro skill `s` s ratingem R a příklad s obtížností D):

```
expected = 1 / (1 + 10 ^ ((D - R) / 400))
actual   = 1.0 pokud správně a reakce ≤ 3000 ms
           0.7 pokud správně a reakce > 3000 ms
           0.0 pokud špatně nebo minul
K = 32 dokud attempts < 20, pak 16
R_new = R + K * (actual - expected)
R_new = clamp(R_new, 600, 1800)
```

### 8.2 Výběr další dovednosti (ProblemGenerator)

1. Z povolených dovedností v Settings vyfiltruj aktivní.
2. Pro každou spočti `weight = max(0, 1500 - rating)` (nízký rating ⇒ vyšší váha).
3. Normalizuj na pravděpodobnosti.
4. S pravděpodobností **0.15** injektuj **snadnou** (nejvyšší rating) - zabraňuje frustraci.
5. S pravděpodobností **0.10** injektuj **o stupeň těžší** - podporuje růst.
6. Jinak vyber dle vah.

### 8.3 Generování 3 odpovědí

1 správná + 2 **plausibilní** špatné. Distraktory volíme z těchto heuristik (dle operace):

- Sčítání: ±1, ±2, cifrová chyba (záměna jednotek/desítek), správný výsledek ±10.
- Odčítání: prohození operandů, ±1, zapomenutá výpůjčka.
- Násobilka: sousední násobek (`a*(b±1)`), nebo `a+b` (typická chyba).
- Dělení: sousední kvocient, `a-b`.

Distraktory nesmí být:
- Stejné jako správná odpověď.
- Záporné (pro 1.-2. třídu).
- Duplicitní mezi sebou.

Pokud heuristika selže, fallback: `correct ± random(1..5)`.

### 8.4 Adaptivní rychlost

```
base_speed_px_s = 120
streak_mult    = 1.0 + min(streak, 10) * 0.03
rating_mult    = 1.0 + (avg_rating - 1000) / 1000   ; clamp [0.7, 1.6]
speed = base * streak_mult * rating_mult
```

Při 3+ chybách v řadě: `speed *= 0.8` dokud není 2x správně.

## 9. Herní smyčka (GameController)

```
STATE_MACHINE: IDLE → COUNTDOWN → PLAYING → ENDING → RESULT

IDLE:
  - čeká na start z MainMenu

COUNTDOWN (3 s):
  - zobrazí "3, 2, 1, START!"
  - přehraje round_start SFX
  - vytvoří sessions row, emituje round_started

PLAYING:
  - loop: spawn problem → animace pád → klik nebo miss → log → další
  - každou frame update timer; když ≤ 0 → ENDING
  - max 1 aktivní problem najednou (MVP)

ENDING:
  - stop spawn, nechat doletět aktuální (nebo skrýt)
  - vypočítat summary (accuracy, best_streak, final_score)
  - update sessions row, emituje round_ended
  - spáruje dovednosti co posunuly rating, zkontroluje odemknutí

RESULT:
  - přechod na scenes/results
```

## 10. UI wireframy (ASCII)

### 10.1 Main Menu

```
┌────────────────────────────────────────────────────┐
│                                                    │
│                 MATHLINGS                          │
│                                                    │
│           ┌──────────────────┐                     │
│           │     HRÁT! ▶       │                    │
│           └──────────────────┘                     │
│                                                    │
│           ┌──────────────────┐                     │
│           │   Statistiky 📊  │                     │
│           └──────────────────┘                     │
│                                                    │
│  profil: Vojta 👦       nastavení⚙    rodič🔒      │
└────────────────────────────────────────────────────┘
```

### 10.2 Game Screen

```
┌────────────────────────────────────────────────────┐
│ 🏆 Skóre: 120       série: 🔥x3      ⏱ 1:23        │
│ ═══════════════════════════════════════            │
│                                                    │
│            ╭────────╮                              │
│            │  7+5   │  ← padá dolů                 │
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
│                  Super práce! 🎉                   │
│                                                    │
│              Skóre: 240 ⭐⭐⭐                      │
│              Přesnost: 87 %                        │
│              Nejdelší série: 12 🔥                 │
│                                                    │
│     Odemkl jsi: Téma Vesmír 🚀                     │
│                                                    │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    │
│   │ Hrát znovu│   │ Statistiky│   │  Menu     │    │
│   └──────────┘    └──────────┘    └──────────┘    │
└────────────────────────────────────────────────────┘
```

### 10.4 Parent Gate

```
┌────────────────────────────────────────────────────┐
│        Pouze pro rodiče                            │
│                                                    │
│        Kolik je  17 × 8 ?                          │
│                                                    │
│        ┌─────────────┐                             │
│        │             │                             │
│        └─────────────┘                             │
│                                                    │
│             [Potvrdit]                             │
└────────────────────────────────────────────────────┘
```

## 11. Testovací strategie

- **Unit (GUT):** ProblemGenerator (distribuce, validita distraktorů), SkillModel (Elo update, clamp), AnswerValidator, DAOs (integrace s in-memory SQLite).
- **Ruční smoke:** Po každém WP spusť Main Menu → Hrát → ukončit kolo → Result.
- **Cílové pokrytí:** ≥ 80 % `scripts/tutor/` a `scripts/game/` (zbytek UI testujeme ručně).

## 12. Build & deployment

- **macOS dev:** Otevři `project.godot` v Godot editoru 4.3+.
- **Android export:** Nainstaluj export templates, nakonfiguruj Android SDK, debug keystore. AAB pro release.
- **CI (později):** GitHub Actions workflow `.github/workflows/build.yml` — export Android + unit testy.

## 13. Otevřené otázky / rozhodnuto později

- [ ] Grafický styl - konkrétní art direction (může být placeholder → finální v P12).
- [ ] Hudba - vlastní vs. CC0 pack.
- [ ] Přidání časových výzev a turnajů (v2).
- [ ] Podpora dvou dětí na stejném tabletu (profily jsou připraveny, UX později).

## 14. Glossary

- **WP** = Work Package (`specs/Pxx_*.md`), jednotka práce pro subagenta.
- **Skill** = jednoznačně pojmenovaná dovednost sledovaná Elo ratingem.
- **Distractor** = jedna ze dvou špatných odpovědí v trojici.
- **Streak** = počet správných odpovědí za sebou v aktuálním kole.
- **Combo** = multiplier bodů odvozený od streak (1× / 1.5× / 2× / 3×).
