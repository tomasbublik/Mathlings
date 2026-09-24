# P20 — Vesmírný motiv: lightsaber zvuk + barevné rozprasknutí objektů

**Tier:** Sonnet 4.6 · **Wave:** 5 · **Deps:** P3 (AudioManager), P11 (VFX), P12 (ThemeManager), P19 (per-skin splash palette infrastructure).

## Scope

Pro motiv „Vesmír" (`space`) je herní zážitek aktuálně identický s ovocem — stejný zvuk, stejné barevné částice. Cíl udělat ho výrazně odlišný:

1. **Theme-aware correct SFX chain.** Při uhodnutí v space motivu zní napřed *light saber swoosh*, po ~0.3 s druhý zvuk *space explosion*. V ostatních motivech (fruit, balloons) zůstává jediný `correct.wav`.
2. **Per-objekt explosion palety.** Vesmírné objekty se rozprsknou do barev odpovídajících skutečnému objektu:
   | Skin | Hlavní barvy úlomků |
   |---|---|
   | Meteorit (`skin_meteor.svg`) | tmavě hnědá + oranžovo-červená (rozžhavená kůra) |
   | Hvězda (`skin_star.svg`) | bílá + zlatá |
   | Satelit (`skin_satellite.svg`) | stříbrná + černá + tyrkysová (panely) |
   | Vesmírná loď (NEW: `skin_spaceship.svg`) | šedá + červená (motory) |
   | Marťanský talíř (NEW: `skin_ufo.svg`) | světle zelená + chrom + fialová |
3. **Rozšíření katalogu skinů** ve space motivu: stávající 3 (meteor, star, satellite) + 2 nové (spaceship, ufo) = 5.
4. **Visual polish úlomků.** Místo kulových částic použít trojúhelníkové kovové úlomky (`shard.svg`).

**Mimo scope:** balloons motiv polish (samostatný WP), úprava fruit motivu (P19).

## Files to create / modify

- `assets/audio/sfx/lightsaber.wav` — krátký swoosh (~0.4 s).
- `assets/audio/sfx/space_explosion.wav` — explosion (~0.6 s).
- `assets/images/skins/skin_spaceship.svg`, `skin_ufo.svg` — nová SVG.
- `assets/images/particles/shard.svg` — kovový úlomek (trojúhelník).
- `scripts/autoload/audio_catalog.gd` — přidat dva nové SFX klíče.
- `scripts/autoload/theme_manager.gd` — rozšířit `space` motiv o nové skiny + paletky (struktura z P19) + **nová metoda `current_correct_sfx_chain() -> Array[Dictionary]`** vracející sekvenci `[{key, delay_ms}]`.
- `scripts/autoload/audio_manager.gd` — přidat metodu `play_sfx_chain(chain: Array)` která sekvenčně přehrává SFX s definovanými delay.
- `scripts/game/game_controller.gd` — místo `_play_sfx("correct")` volat `AudioManager.play_sfx_chain(ThemeManager.current_correct_sfx_chain())`.
- `scenes/game/vfx/space_explosion.tscn` + `.gd` — analogicky `FruitExplosion` z P19, ale s shard.svg a paletou pro space objekt.
- `scenes/game/falling_problem.gd` — pro space motiv instancuj `SpaceExplosion` místo `FruitExplosion` (rozhodne ThemeManager).

## ThemeManager rozšíření

```gdscript
"space": {
    "label": "Vesmír",
    "background": "res://assets/images/backgrounds/bg_space.svg",
    "skins": [
        {"texture": "res://assets/images/skins/skin_meteor.svg",
         "splash_palette": [Color(0.4, 0.2, 0.1), Color(1.0, 0.4, 0.1)]},
        {"texture": "res://assets/images/skins/skin_star.svg",
         "splash_palette": [Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.3)]},
        {"texture": "res://assets/images/skins/skin_satellite.svg",
         "splash_palette": [Color(0.8, 0.8, 0.85), Color(0.1, 0.1, 0.15), Color(0.3, 0.85, 0.95)]},
        {"texture": "res://assets/images/skins/skin_spaceship.svg",
         "splash_palette": [Color(0.6, 0.6, 0.65), Color(1.0, 0.2, 0.2)]},
        {"texture": "res://assets/images/skins/skin_ufo.svg",
         "splash_palette": [Color(0.5, 0.95, 0.5), Color(0.85, 0.85, 0.95), Color(0.7, 0.4, 0.95)]},
    ],
    "game_music": "game_space",
    "correct_sfx_chain": [
        {"key": "lightsaber", "delay_ms": 0},
        {"key": "space_explosion", "delay_ms": 350},
    ],
    "vertical_direction": 1,
    "default_unlocked": true,
},
```

Pro fruit + balloons motivy `correct_sfx_chain` defaultuje na `[{"key": "correct", "delay_ms": 0}]`.

## AudioManager API doplnění

```gdscript
## Plays an ordered list of SFX with optional delays.
##   chain: Array[Dictionary], each {"key": String, "delay_ms": int}
## Each delay is measured from the start of the chain (not cumulative).
## Skips silently if SFX disabled or chain is empty.
func play_sfx_chain(chain: Array) -> void
```

Implementace: pro každý prvek vytvořit `Timer.new()` s `wait_time = delay_ms / 1000.0`, na timeout `play_sfx(key)`, po prvním tick `queue_free()`. Alternativa s `await get_tree().create_timer(...)` je jednodušší a stačí.

## SpaceExplosion scéna

Stejná struktura jako FruitExplosion (P19), ale:
- Particle texture: `shard.svg` (trojúhelník).
- Multi-color: pokud paleta má 3+ barvy, pošli per-particle barvu cyklicky (Godot CPUParticles podporuje `color_initial_ramp`).
- Rotation: shards rotují (`angular_velocity` 0.5–3.0 rad/s).
- Žádný „watery splash" layer — pro vesmír to nesedí. Místo něj jemný „dým/prach" particle (šedo-bílé, opacity 0.3).

## Definition of Done

1. Změna motivu na „Vesmír" → po správné odpovědi zní lightsaber + 0.35 s později výbuch.
2. Po výbuchu se objekt rozprskne v paletě dle skinu (meteorit má jiné barvy než UFO).
3. Změna motivu zpět na „Ovoce" → opět jen `correct.wav` + per-fruit fruit explosion (P19 chování zachováno).
4. Žádný SFX se nesdílí mezi motivy (lightsaber se nehraje v ovoci).
5. Spaceship + UFO skiny jsou viditelně odlišné od stávajících 3 skinů.
6. Test: 100× spawn ve space motivu na Android telefonu — žádné FPS dropy, žádné memory leaky.

## Otevřené otázky

- **Lightsaber zvuk licencování.** Skutečný Star Wars lightsaber je trademarked. Spec předpokládá *generický „energy sword swoosh"* CC0 sample (např. Freesound.org). Pojmenování `lightsaber.wav` je jen interní; v UI textu se to nazve „energetický meč".
- **Délka chain pro fruit.** Aktuálně default je 1-prvkový chain. Pokud někdy chceme pro fruit přidat zvonek po `correct`, jen prodloužíme chain v ThemeManager — žádná code change.

## Implementation log

- AudioCatalog rozšířen o klíče `lightsaber` a `space_explosion`. Reálné WAV soubory ještě nejsou dodány — AudioManager u nich tiše loguje warning a pokračuje (graceful degradation).
- ThemeManager:
  - Nové konstanty `DEFAULT_CORRECT_CHAIN` (single "correct") a `DEFAULT_EXPLOSION_SCENE` (= fruit_explosion.tscn).
  - Schema rozšířeno o nepovinné klíče `correct_sfx_chain` a `explosion_scene` per motiv. Vesmír používá `[lightsaber@0ms, space_explosion@350ms]` + `space_explosion.tscn`.
  - Space katalog skinů má 5 položek (přidány spaceship + ufo s odpovídajícími paletami).
  - Helpery `current_correct_sfx_chain()` a `current_explosion_scene_path()` (oba defaultují na hodnoty výše).
- AudioManager.play_sfx_chain(chain) — schedule přes `SceneTreeTimer` (ne ručně spravovaný Timer node), takže navigace mezi scénami timery automaticky uklidí. Delays nejsou kumulativní, jsou measured-from-start (chain je „audio storyboard").
- GameController._apply_correct: místo `_play_sfx("correct")` volá `_play_sfx_chain(ThemeManager.current_correct_sfx_chain())`. Nový wrapper `_play_sfx_chain` respektuje stejný `_emit_side_effects` flag jako `_play_sfx`.
- FallingProblem: hardcoded `FRUIT_EXPLOSION_VFX` zmizel. `explode_correct` načítá scénu přes `_resolve_explosion_scene()` (= load `ThemeManager.current_explosion_scene_path()`), instancuje a duck-typed volá `setup(splash_color)`. Fallback na FruitExplosion když path nenajde validní scénu.
- Nové assety:
  - `assets/images/skins/skin_spaceship.svg` (raketa s motorem)
  - `assets/images/skins/skin_ufo.svg` (chrome talíř s tractor lights)
  - `assets/images/particles/shard.svg` (trojúhelníkový kovový úlomek pro debris)
- `scenes/game/vfx/space_explosion.tscn` + `.gd` (`class_name SpaceExplosion`) — Shards (rotace + multi-color via `splash_color`) + Dust (šedá pasivní mlha). Stejný 2-layer counter cleanup jako FruitExplosion.
- Testy v `test_theme_manager.gd` rozšířeny o 5 nových: chain klíče existují v AudioCatalog, default chain je single "correct", space chain je [lightsaber, explosion+350ms], explosion_scene paths existují, default scene path je validní.
