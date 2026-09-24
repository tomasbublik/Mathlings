# P11 — Particle efekty + VFX (Visual Polish)

**Tier:** Sonnet 4.6 · **Wave:** 4 (polish) · **Deps:** P7, P10.

## Scope

Nahrazení dočasných vizuálních efektů (zatím řešených jen přes Tween) za plnohodnotné particle systémy a vizuální feedback. Zahrnuje explozi při správné odpovědi, "rozprsknutí" při špatné a prachový obláček při dopadu (miss). Přidává také plovoucí text (+bodové skóre a combo) v místě exploze.

Z důvodu maximální kompatibility se staršími Android zařízeními preferujeme `CPUParticles2D`.

## Files to create / modify

- `scenes/game/vfx/correct_particles.tscn` — Particle systém (hvězdičky/konfety) pro správnou odpověď.
- `scenes/game/vfx/wrong_particles.tscn` — Tmavší oblak/křížky pro chybu.
- `scenes/game/vfx/miss_particles.tscn` — Prachový mráček pro dopad.
- `scenes/game/vfx/floating_text.tscn` — Animovaný Label (posun nahoru + fade out).
- **Úprava:** `scenes/game/falling_problem.gd` — napojení nových instancí na události.
- **Úprava:** `scenes/game/game.gd` — spawning floating textu při skórování.

## Požadavky

1. **CPUParticles2D:** Vytvořit samostatné scény pro efekty, které obsahují `CPUParticles2D` s nastaveným `one_shot = true`. Na signál `finished` se scéna sama smaže (`queue_free()`).
2. **Floating Text:** Malá scéna s `Label`, která má metodu `setup(text: String, color: Color)`. Při instancování spustí Tween, který text posune na Y o -50 px, změní alpha na 0 a po dokončení se odstraní.
3. **Integrace do `FallingProblem`:** Metody `explode_correct()`, `explode_wrong()` a `splash()` nyní instancují odpovídající VFX scény na své globální pozici do rodičovského uzlu (aby částice padaly volně i poté, co problem zmizí) a následně skryjí samotný sprite.
4. **Combo feedback:** Pokud `combo > 1`, `floating_text` by měl zobrazit `+15 (1.5x)`.

## Definition of Done

1. V herní scéně jsou po úspěšném, chybném a zmeškaném příkladu vidět patřičné částicové efekty.
2. Správná odpověď generuje stoupající text s obdrženým skóre.
3. Částicové systémy a texty se po přehrání animace korektně mažou z paměti (`queue_free`).
4. Vše funguje i v nejnižším `speed_preset` plynule.

## Otevřené otázky

- _Zatím žádné._
