# P9 — Skill Model (Elo + výběr dovednosti)

**Tier:** Opus 4.7 · **Wave:** 2 · **Deps:** P2 (DAO).

## Scope

Adaptivní tutor: drží Elo rating per dovednost, updatuje po každém pokusu, vybírá další dovednost. Řídí adaptivní rychlost pádu.

**Mimo scope:** generování konkrétního příkladu (P1), herní smyčka (P10).

## Files to create

- `scripts/tutor/skill_model.gd` — `class_name SkillModel`.
- `scripts/tutor/difficulty_controller.gd` — `class_name DifficultyController`.
- `scripts/tutor/attempt_logger.gd` — `class_name AttemptLogger`.
- `tests/unit/test_skill_model.gd` — GUT (kritické pokrytí).

## Veřejné API

```gdscript
class_name SkillModel

## In-memory cache per profile. Při konstrukci načte z DB.
func _init(profile_id: int, db) -> void

## Vrací aktuální rating pro skill_key (default 1000).
func rating_for(skill_key: String) -> float

## Aplikuje Elo update po pokusu. Persistuje do DB.
## correct: 0/1, reaction_ms: < 0 pokud miss.
func on_attempt(skill_key: String, difficulty: float, correct: bool, reaction_ms: int) -> float  ## vrací nové rating

## Vybere skill_key pro další problém z enabled množiny.
func choose_next(enabled_keys: PackedStringArray, rng: RandomNumberGenerator = null) -> String
```

```gdscript
class_name DifficultyController

## base_speed_px_s = 120
func speed_for(avg_rating: float, streak: int, recent_errors: int) -> float
```

```gdscript
class_name AttemptLogger

func _init(session_id: int, db) -> void
func log(problem: Dictionary, chosen_index: int, reaction_ms: int, shown_at_ms: int, resolved_at_ms: int) -> void
```

## Algoritmus Elo (viz DESIGN §8.1)

```
expected = 1 / (1 + 10 ^ ((D - R) / 400))
actual   = 1.0 if correct and reaction_ms <= 3000 else
           0.7 if correct else
           0.0
K = 32 while attempts < 20 else 16
R_new = clamp(R + K * (actual - expected), 600, 1800)
```

> `reaction_ms < 0` (miss) se počítá jako `actual = 0.0`.

## Algoritmus výběru (viz DESIGN §8.2)

```
pool := enabled_keys
weights[k] := max(0.01, 1500 - rating_for(k))
normalize weights → probabilities

p := rng.randf()
if p < 0.15:    return argmax(rating_for) over pool            # snadná
elif p < 0.25:  return sample_by_index(pool, harder_by_one)    # o kousek těžší
else:           return weighted_sample(pool, probabilities)    # dle vah
```

Kde `harder_by_one`:
- Posuň v rámci rodiny (`add_0_20` → `add_0_100`, `mul_x5` → `mul_x7`).
- Pokud není kam, fallback na weighted_sample.
- Mimo `enabled_keys` nikdy nesahej.

## Rodina (pro "harder_by_one")

```gdscript
const FAMILIES := {
    "add": ["add_0_10", "add_0_20", "add_0_100"],
    "sub": ["sub_0_10", "sub_0_20", "sub_0_100"],
    "mul": ["mul_x2","mul_x3","mul_x4","mul_x5","mul_x6","mul_x7","mul_x8","mul_x9","mul_x10"],
    "div": ["div_0_100"],
}
```

## Adaptivní rychlost (DifficultyController)

```
base_speed = 120
streak_mult = 1.0 + clamp(streak, 0, 10) * 0.03
rating_mult = clamp(1.0 + (avg_rating - 1000) / 1000, 0.7, 1.6)
speed = base * streak_mult * rating_mult
if recent_errors >= 3: speed *= 0.8
```

`recent_errors` = počet chyb v posledních 5 pokusech.

## Testy (kritické)

- `test_elo_update_correct_fast`: R=1000, D=1000, correct=true, reaction_ms=1500 → R se zvýší o ~16 (K=32, actual=1, expected=0.5).
- `test_elo_update_wrong`: stejné podmínky, correct=false → R klesne o ~16.
- `test_elo_clamps`: mnoho správných ve význě těžké → R ≤ 1800; mnoho špatných → R ≥ 600.
- `test_k_transitions`: po 20 attempts se K přepne z 32 na 16.
- `test_choose_next_prefers_weakness`: 3 skilly (R=600, 1000, 1400), 10000 výběrů → distribuce ≈ odpovídá vážení (>60% na R=600).
- `test_choose_next_honors_enabled`: enabled_keys = jen podmnožina → výsledek vždy v podmnožině.
- `test_choose_next_harder_injection`: měj skill `add_0_20`, vytáhni 1000x; aspoň ~10% jsou `add_0_100`.
- `test_difficulty_speed_bounds`: avg_rating=500 → mult 0.7; avg=2000 → 1.6.
- `test_difficulty_speed_error_slowdown`: recent_errors=3 → násobitel 0.8.

## Definition of Done

Společné + všechny testy ≥ 90 % pokrytí `skill_model.gd` + `difficulty_controller.gd`. Žádné výjimky nebo warningy.

## Otevřené otázky

- Spec vyžaduje metodu `AttemptLogger.log()`, ale `log` je globální built-in v GDScript (`SHADOWED_GLOBAL_IDENTIFIER` warning). Implementace proto používá `log_attempt()`. Pokud je to problém, je třeba aktualizovat volající v P10.

## Implementation log

- `SkillModel` drží per-profile cache `skill_key → {rating, attempts, correct}`, načítá z `SkillsDao.get_for_profile` při konstrukci a persistuje po každém `on_attempt` přes `SkillsDao.upsert`.
- Při `_db == null` (unit testy) je vše in-memory; `EventBus.skill_rating_changed` se emituje jen s připojenou DB.
- `choose_next` implementuje 15 % easy injection (argmax rating) + 10 % harder-by-one (z rodin v `FAMILIES`) + 75 % weighted sample (`max(0.01, 1500 - rating)`); výběr vždy zůstává v `enabled_keys`.
- `DifficultyController` je stateless (static `speed_for`), vzorec dle DESIGN §8.4 s clampy.
- `AttemptLogger.log_attempt()` (viz Otevřené otázky výše pro jméno) delegovaný na `AttemptsDao.insert`.
- GUT testy pokrývají Elo směr+magnitude, clamp hranice, K přechod na 20. pokusu, weakness bias, honoring `enabled_keys`, harder injection frekvenci, speed mult bounds a error slowdown.
