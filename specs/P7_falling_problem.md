# P7 — Falling Problem (entita + animace)

**Tier:** Sonnet 4.6 · **Wave:** 2 · **Deps:** P1 (Problem kontrakt), P6 (skin texture).

## Scope

Vizuální reprezentace jednoho padajícího příkladu. Node, který:
- Zobrazí skin (obrázek) + text výrazu (`"7 + 5"`).
- Animuje pád shora dolů rychlostí v `px/s`.
- Emituje signály při kliknutí odpovědi nebo při dopadu na zem.
- Podporuje "zničit" animaci (správná = konfety, špatná = scvrknutí, miss = splash).

**Mimo scope:** výběr odpovědí / tlačítka (to je součást herní scény v P10), spawn logic (to je GameController).

## Files to create

- `scenes/game/falling_problem.tscn`
- `scenes/game/falling_problem.gd` — `class_name FallingProblem extends Node2D`.

## Veřejné API

```gdscript
class_name FallingProblem
extends Node2D

signal landed(problem_id: int)     ## dopadl na Y = floor_y bez odpovědi

@export var floor_y: float = 700.0

## Inicializace. problem = Dictionary dle DESIGN §7.1. Skin = path k Texture2D.
func setup(problem: Dictionary, speed_px_s: float, skin_texture: Texture2D) -> void

## Správná odpověď - hezká explode animace, pak queue_free po animaci.
func explode_correct() -> void

## Špatná odpověď - scvrknout, spadnout rychleji, queue_free po animaci.
func explode_wrong() -> void

## Volá se, když dopadne na zem (game controller detekuje; ale entita to umí sama).
func splash() -> void
```

## Struktura scény

```
FallingProblem (Node2D)
├── Skin (Sprite2D)          ← textura ze setup()
├── Expression (Label)        ← text "7 + 5", centrován, bold, 48pt
├── LandDetector (Area2D)     ← 1×1 px v pivotu, pro rychlou kolizi (jen pokud to dává smysl)
└── FxLayer (Node2D)          ← kam se přidávají particles/tweens
```

## Chování

1. Po `setup()` umísti uzel na `position = Vector2(random_x, -100)` (volající nastaví x, tenhle modul jen akceptuje výchozí `position`).
2. V `_process(delta)` přičítej `position.y += speed * delta`.
3. Když `position.y >= floor_y` a entita **ještě nebyla vyřešena** → volá `splash()`, emituje `landed(problem_id)`, stop `_process`.
4. `explode_correct/wrong/splash` nesmí emitovat `landed`.
5. Po explodování nastav `set_process(false)` a spusť tween ~0.4 s, pak `queue_free()`.
6. Text výrazu je přes skin centrálně; při kolizi s horní třetinou obrazovky neposouvej kameru.

## Vstup

Entita sama **nečte input**. Volající (game controller) po kliknutí tlačítka rozhodne a zavolá `explode_correct()` nebo `explode_wrong()`.

## Testy

GUT není kritický; stačí smoke scéna, která spawnne 3 instance a ověří, že po `explode_correct` jsou free do 1 s.

## Definition of Done

Společné + manuálně: otevři `scenes/game/falling_problem.tscn` v Godotu, spusť test scénu (dočasnou), uvidíš padající "7+5", po chvíli splash. `explode_correct()` ukáže particle efekt.

## Otevřené otázky

_(vyplní agent)_

## Implementation log

- `FallingProblem` vytvořen jako `Node2D` se scénou (Sprite2D + Label + FxLayer).
- Používá `skin_apple.svg` jako výchozí texturu; volající (Game scéna) může předat jinou v `setup()`.
- `explode_correct`/`explode_wrong`/`splash` jsou čistě tween-based (žádné particles ve Wave 2 — P11 přidá VFX později). `set_process(false)` po vyřešení zabraňuje dalšímu pádu.
- `landed` signál se emituje jen jednou; entita si interně drží `_resolved` flag.
