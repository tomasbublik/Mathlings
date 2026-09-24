# P1 — Problem Generator

**Tier:** Sonnet 4.6 · **Wave:** 1 (paralelní) · **Deps:** žádné (jen DESIGN.md §6.2, §7.1, §8.3)

## Scope

Čistá knihovna bez UI. Generuje jeden matematický příklad pro zadaný `skill_key`, včetně 3 odpovědí (1 správné + 2 plausibilní distraktorů). Výstupem je `Dictionary` odpovídající kontraktu `Problem` (viz DESIGN §7.1).

**Mimo scope:** výběr dovednosti (to dělá `SkillModel` v P9), Elo update, logování, UI.

## Files to create

- `scripts/game/problem.gd` — pouze konstanty a helper funkce (validace Problem dict).
- `scripts/game/problem_generator.gd` — `class_name ProblemGenerator`, statické/instanční API.
- `tests/unit/test_problem_generator.gd` — GUT test.

## Veřejné API

```gdscript
class_name ProblemGenerator

## Vytvoří Problem pro zadaný skill_key. RNG je injectable pro testovatelnost.
## Vrací Dictionary dle §7.1. Pokud je skill_key neznámý, vrací {}.
static func generate(skill_key: String, rng: RandomNumberGenerator = null) -> Dictionary

## Vrací aktuální schema-compatible seznam podporovaných skill klíčů.
static func supported_skills() -> PackedStringArray
```

## Požadované chování

1. Operace a rozsahy **přesně** podle DESIGN §6.2.
2. Dělení generuj z násobení (vyber b ∈ [2,10], q ∈ [2,10], a = b*q), aby dělilo beze zbytku.
3. Odčítání: vždy `a ≥ b` (žádné záporné výsledky pro 1.-2. třídu).
4. Distraktory podle DESIGN §8.3. Zajisti:
   - Žádné duplicity (`correct ∉ distractors`, `distractors[0] ≠ distractors[1]`).
   - Žádné záporné hodnoty.
   - Pokud heuristika 3× selže, fallback `correct ± random(1..5)`.
5. Pořadí `choices` zamíchej; `correct_index` ukazuje na správnou.
6. `difficulty` D odpovídá tabulce v DESIGN §6.2.
7. `id` **negeneruje** tenhle modul (nastaví ho volající z auto-inkrementu session).

## Testy (GUT, pokrytí ≥ 90 % tohoto modulu)

- Pro každý `skill_key` v `supported_skills()`:
  - 500 vygenerovaných problémů: všechny validní (správná odpověď skutečně platí pro `expression`).
  - `choices.size() == 3`, žádné duplicity, žádné záporné.
  - `choices[correct_index] == correct_answer`.
- `add_0_20`: součet ≤ 20; `sub_0_100`: rozdíl ≥ 0; `mul_x7`: jeden operand je 7; `div_0_100`: dělí beze zbytku.
- Neznámý skill_key vrací `{}`.
- Se stejným seedem RNG dostaneš stejný výsledek (determinismus pro debug).

## Definition of Done

Společné z `specs/README.md` + všechny testy v `tests/unit/test_problem_generator.gd` zelené.

## Otevřené otázky

Žádné.

## Implementation log

### Vytvořené soubory

- `scripts/game/problem.gd` — třída `Problem` s konstantami `REQUIRED_KEYS`, `DIFFICULTY` (per DESIGN §6.2) a statickou metodou `is_valid(problem: Dictionary) -> bool`.
- `scripts/game/problem_generator.gd` — třída `ProblemGenerator` se statickými metodami `generate()` a `supported_skills()`. Modul je bezstavový, RNG je injectable.
- `tests/unit/test_problem_generator.gd` — GUT unit testy pokrývající všechny body ze sekce "Testy" (500 problémů per skill, per-skill invarianty, determinismus, is_valid(), difficulty hodnoty, id=0, míchání choices).

### Klíčové implementační rozhodnutí

**Distraktory per operace (DESIGN §8.3):**
- Sčítání: ±1, ±2, ±10 (cifrová chyba / záměna desítek).
- Odčítání: ±1, ±10 (zapomenutá výpůjčka), 3×correct (simulace prohozených operandů).
- Násobilka: correct±k (sousední násobek), k+b (záměna násobení za sčítání).
- Dělení: ±1, ±2 (sousední kvocient).
- Garantovaný fallback (3 fáze): náhodné ±1..5, pak deterministické +1, +2…

**Generování výrazů:**
- Dělení generováno z násobilky: b∈[2,10], q∈[2,10], a=b×q — zaručuje celočíselný výsledek.
- Odčítání: vždy a≥b, výsledek ≥ 0.
- `add_0_10`: oba operandy ≤ 10, součet ≤ 10.
- `add_0_20`: operandy ≤ 19, součet ≤ 20.

**Zamíchání choices:** Fisher-Yates s injectable RNG; `correct_index` = `choices.find(correct)` po zamíchání.

**Pole `id`:** nastaveno na 0 — volající (GameController/SkillModel) přiřazuje auto-inkrement per session.

### Godot verze

Projekt detekován jako Godot 4.6.2. Godot ve headless --check-only módu nelze spustit v CI prostředí (hang bez display), syntaxe ověřena manuálně.

### Testy

GUT testy jsou připraveny pro běh přes GUT addon (není součástí P1). Čekají na instalaci addonu v P2/pozdější vlně.
