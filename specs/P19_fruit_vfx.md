# P19 — Šťavnaté efekty rozprsknutí ovoce (Fruit theme polish)

**Tier:** Sonnet 4.6 · **Wave:** 5 · **Deps:** P7 (FallingProblem), P11 (VFX foundation), P12 (ThemeManager).

## Scope

Aktuálně: každé „ovoce" (zatím jen `skin_apple.svg`) při uhodnutí explodue do žluto-zlatých částic z `correct_particles.tscn`. Pro 8letého hráče to nemá „šťávu". Cíl:

1. **Minimálně 10 druhů ovoce** ve `fruit` motivu, každý s vlastním SVG skinem **a vlastní explosion paletou**.
2. **Per-ovoce explosion barva** odpovídající skutečné dužině:
   | Ovoce | Skin (vně) | Exploze (uvnitř) |
   |---|---|---|
   | Jablko | červená | světle žluto-bílá |
   | Banán | žlutá | krémová |
   | Hruška | zelená | bílá |
   | Jahoda | červená | sytě růžová |
   | Borůvka | tmavě modrá | světle fialová |
   | Pomeranč | oranžová | světle oranžová |
   | Citron | žlutá | bledě žlutá |
   | Meloun | zelená | sytě červená + černá zrnka |
   | Hroznové víno | tmavě fialová | světle zelená |
   | Broskev | broskvová | tmavě oranžová |
3. **Watery splash** efekt: kromě barevných částic přibude radiální „cákanec" jako voda — světle modré drops s gravity, krátký lifetime, vyšší rychlost. Vrstvený nad explosion particles.
4. **Random fruit volba** při spawnování. Stávající ThemeManager `current_skin_textures()` už vrací array — používáme jen [0] (apple). Tento WP zařídí náhodný výběr.
5. **Particle texture upgrade.** Místo plné kruhové částice použít custom kapku (`assets/images/particles/drop.svg`).

**Mimo scope:** zvuková nadstavba — ta je v P20 pro vesmír. Ovoce SFX zůstává `correct.wav`.

## Files to create / modify

- `assets/images/skins/skin_*.svg` — **přidat 9 nových** (banana, pear, strawberry, blueberry, orange, lemon, watermelon, grape, peach). Apple už existuje.
- `assets/images/particles/drop.svg` — vodní kapka (jeden tvar, default white, tinted z Particle node).
- `scripts/autoload/theme_manager.gd` — rozšířit `THEMES["fruit"]["skins"]` o všech 10 cest a přidat paralelní `["splash_palettes"]: Array[Color]` per skin (index aligned).
- `scenes/game/vfx/fruit_explosion.tscn` + `.gd` — **nová scéna**, `class_name FruitExplosion`. Spojuje 2 vrstvy:
  - `CPUParticles2D` pro „dužinu" (barva z parametru).
  - `CPUParticles2D` pro vodní cákanec (světle modrý, drop.svg).
- `scenes/game/falling_problem.gd` — místo `CORRECT_VFX` instancuj `FruitExplosion` a předej barvu z ThemeManager.
- `scripts/autoload/theme_manager.gd` — nová metoda:
  ```gdscript
  func current_skin_with_palette() -> Dictionary:
      ## { "texture": Texture2D, "splash_color": Color }
  ```
- `scenes/game/game.gd` — předávat `splash_color` do FallingProblem během spawnu, ten ho dál do FruitExplosion.

## ThemeManager rozšíření

```gdscript
"fruit": {
    "label": "Ovoce",
    "background": "res://assets/images/backgrounds/bg_sky.svg",
    "skins": [
        {"texture": "res://assets/images/skins/skin_apple.svg",      "splash": Color(1.0, 0.95, 0.7)},
        {"texture": "res://assets/images/skins/skin_banana.svg",     "splash": Color(1.0, 0.92, 0.6)},
        {"texture": "res://assets/images/skins/skin_strawberry.svg", "splash": Color(1.0, 0.4, 0.5)},
        {"texture": "res://assets/images/skins/skin_watermelon.svg", "splash": Color(0.95, 0.25, 0.3)},
        ...
    ],
    "game_music": "game",
    "vertical_direction": 1,
    "default_unlocked": true,
},
```

> Schema změna: `skins` se mění z `Array[String]` na `Array[Dictionary]`. **Aktualizovat všechny callery** — `current_skin_texture()`, `current_skin_textures()`, P12 spec, settings preview.

## FruitExplosion API

```gdscript
class_name FruitExplosion
extends Node2D

func setup(splash_color: Color) -> void
    ## Aplikuje barvu na první particle layer; spustí emitting; po `finished` queue_free().
```

Particle parametry (laděno na 60 FPS s 8letým hráčem v hlavě):
- Layer 1 (dužina): 40 částic, lifetime 0.7 s, spread 360°, initial_velocity 200–350, gravity (0, 800), scale 4–8, color = splash_color.
- Layer 2 (vodní cákanec): 16 částic, lifetime 0.9 s, spread 180° (nahoru), initial_velocity 150–300, gravity (0, 1200), texture = drop.svg, color = Color(0.5, 0.85, 1.0, 0.85).

Obě layers mají `one_shot = true`, finished signál → `queue_free` na rodičovské `FruitExplosion` až po obou.

## Random fruit selection

V `game.gd::_on_spawn_requested`:

```gdscript
var skin_meta := ThemeManager.random_skin()  # nová metoda — vybere index náhodně
entity.setup(problem, speed, skin_meta["texture"])
entity.set_splash_color(skin_meta["splash"])
```

`FallingProblem` přidá var `_splash_color: Color = Color.WHITE` a `set_splash_color(color)`. Při explode_correct předá barvu do FruitExplosion.

## Definition of Done

1. Fruit motiv má 10 různých SVG ovocí; pří každém kolem se objevují různé.
2. Po správné odpovědi je vidět explozní efekt v barvě **dužiny daného ovoce**, ne univerzální žlutá.
3. Současně letí pár modrých kapek (watery splash).
4. Žádné regrese: ostatní motivy (space, balloons) fungují identicky jako dnes (jejich `skins` se přepíše do nového Array[Dictionary] formátu, ale chování je stejné).
5. Na střední tržní Android tabletu (~Snapdragon 7xx) zůstává 60 FPS (max 4 současné explosions na obrazovce).
6. Žádné memory leaky — particle scenes po dohrání animace queue_free (verifikace přes Resource monitor v Godot editoru po 100 spawnů).

## Otevřené otázky

- Mám SVG ovoce sám nakreslit (každé ~100 řádků), nebo použít free CC0 set z OpenGameArt? Default: nakreslím (konzistentní styl).
- Vodní cákanec přes shader vs. plain particles? Default: particles + drop.svg (jednodušší + bez compatibility issue na GL Compatibility renderer).

## Implementation log

- 9 nových SVG ovocí v `assets/images/skins/` (banana, pear, strawberry, blueberry, orange, lemon, watermelon, grape, peach), styl drží minimální plochá geometrie + outline jako u stávajícího `skin_apple.svg`.
- `assets/images/particles/drop.svg` — bílá kapka 32×32, tintuje se přes `CPUParticles2D.color`.
- `scenes/game/vfx/fruit_explosion.tscn` + `.gd` — dvojvrstvý particle systém (Pulp + Splash), `setup(splash_color)` aplikuje barvu na pulp layer, oba se po `finished` signálu sečítají v counteru a teprve pak `queue_free()` na rodičovské scéně.
- `ThemeManager.THEMES` schema: `skins` je teď `Array[Dictionary]` se klíči `texture` (res:// cesta) + `splash` (Color). Per-fruit barvy odpovídají dužině (meloun → červená, blueberry → fialová). `space` a `balloons` motivy mají také ekvivalentní per-skin paletky.
- Nové ThemeManager metody: `current_skin_entries()`, `random_skin_for_current(rng)`. Stávající `current_skin_textures()` přepsán na novou strukturu, `current_skin_texture()` taktéž.
- `falling_problem.gd`: `set_splash_color(color)` setter, `_spawn_fruit_explosion(color)` pro explode_correct (preload `FRUIT_EXPLOSION_VFX` místo původního `CORRECT_VFX`).
- `game.gd`: per-spawn lookup přes `ThemeManager.random_skin_for_current(_rng)`, předává texture i splash do entity. Smazána lokální cache `_skin_textures` a `FALLBACK_SKIN_TEXTURE` (ThemeManager má vlastní fallback `FALLBACK_SPLASH`).
- Testy (`test_theme_manager.gd`) rozšířeny o:
  - `test_current_skin_entries_have_texture_and_splash` — pin schema kontraktu.
  - `test_random_skin_for_current_returns_valid_entry` — happy path.
  - `test_random_skin_is_stable_for_seeded_rng` — determinismus pro regresní testy.
