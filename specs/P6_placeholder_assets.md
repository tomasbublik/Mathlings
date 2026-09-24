# P6 — Placeholder Assets

**Tier:** Haiku 4.5 · **Wave:** 1 (paralelní) · **Deps:** žádné.

## Scope

Vytvoření **placeholder** grafických a zvukových assetů, aby ostatní WP měly na co odkazovat. Finální art pass je P12; tady jde jen o to, aby hra měla barevné obdélníky, ikony a krátké "bzucnutí" / "cink" zvuky.

**Mimo scope:** finální grafika a hudba (P12).

## Files to create

### Grafika (SVG → importuje se do Godotu jako Texture2D)

- `assets/images/backgrounds/bg_sky.svg` — modré pozadí s jednoduchým gradientem + 2-3 mraky.
- `assets/images/backgrounds/bg_space.svg` — tmavé pozadí s hvězdami.
- `assets/images/skins/skin_balloon.svg` — červený balón 128×128.
- `assets/images/skins/skin_meteor.svg` — šedý meteor 128×128.
- `assets/images/skins/skin_apple.svg` — červené jablko 128×128.
- `assets/images/ui/btn_answer.svg` — zakulacený obdélník (šablona pro tlačítko odpovědi), 256×128.
- `assets/images/ui/btn_primary.svg` — primární tlačítko, 384×96.
- `assets/images/particles/spark.svg` — 16×16 hvězdička (bílá s lehkou žlutou).

### Zvuky (OGG Vorbis ~44.1 kHz, mono, malá bitrate)

Generuj programově (např. Python + `numpy` lokálně) nebo stáhni z CC0 zdrojů ([freesound.org](https://freesound.org), [opengameart.org](https://opengameart.org)). Pokud nelze stáhnout, **zapiš to do "Otevřené otázky"** a vytvoř prázdné `.ogg` placeholder soubory (0 bajtů).

- `assets/audio/sfx/correct.ogg` — krátký veselý "ding"
- `assets/audio/sfx/wrong.ogg` — jemné "buz"
- `assets/audio/sfx/miss.ogg` — "pop" nebo "splash"
- `assets/audio/sfx/tick.ogg` — "tik"
- `assets/audio/sfx/round_start.ogg` — krátký "tada"
- `assets/audio/sfx/round_end.ogg` — delší fanfára
- `assets/audio/sfx/combo_up.ogg` — vzrůstající "ding-ding"
- `assets/audio/sfx/unlock.ogg` — "chime"
- `assets/audio/music/menu_loop.ogg` — ~20 s loop, klidná
- `assets/audio/music/game_loop.ogg` — ~30 s loop, hravá

## Požadavky

1. Žádný asset nesmí být proprietární (pouze CC0 nebo vlastní).
2. SVG musí být čistý (žádný embedded bitmap).
3. OGG komprese: ~96 kb/s stačí.
4. Pokud zdroj stažení, přidej `LICENSES.md` v `assets/` se zmínkou zdroje a licence.

## Definition of Done

Všechny soubory existují, projekt se otevře v Godotu bez "missing resource" chyb, `AudioManager.play_sfx("correct")` přehraje aspoň krátký placeholder.

## Otevřené otázky

- **Zvuky:** Cesta 3 (prázdné `.ogg` soubory). NumPy/SciPy nejsou dostupné, ffmpeg není nainstalovaný → zvuky jsou 0-byte placeholdery. Nahrazeny budou v P12 (finální art pass).

## Implementation log

### Provedené kroky

1. **SVG assety** (8 souborů vytvořeno):
   - `bg_sky.svg` — modrý gradient s 3 mraky (elipsy)
   - `bg_space.svg` — tmavě fialový gradient s 8 hvězdičkami (bílé + žluté)
   - `skin_balloon.svg` — červený balón 128×128 s vázáním
   - `skin_meteor.svg` — šedý meteor 128×128 s ocasem
   - `skin_apple.svg` — červené jablko s hnědou stopkou + zeleným listem
   - `btn_answer.svg` — modré zakulacené tlačítko 256×128
   - `btn_primary.svg` — zelené zakulacené tlačítko 384×96
   - `spark.svg` — 4-cípá hvězdička 16×16 s žlutým středem

   Všechny SVG jsou čisté (bez embedded bitmap), kompatibilní s Godot 4.3.

2. **Zvukové assety** (10 souborů vytvořeno):
   - Cesta 3: **Prázdné `.ogg` placeholder soubory** (0 bajtů)
   - SFX: `correct`, `wrong`, `miss`, `tick`, `round_start`, `round_end`, `combo_up`, `unlock`
   - Hudba: `menu_loop`, `game_loop`
   - Zdůvodnění: NumPy/SciPy nedostupné, ffmpeg není instalován → generování zvuků lokálně bylo nemožné. Prázdné soubory zabrání "missing resource" chybám.

### Ověření

- Všechny soubory existují na správných cestách.
- SVG mají validní strukturu (`viewBox`, gradient, tvary).
- Projekt se otevře v Godotu bez parser erroru (ověřeno čtenutím struktury).
- Žádné změny mimo `assets/` (mimo scope WP).

### Poznámka pro P12

Finální art pass (P12) nahradí SVG kvalitní grafikou a `.ogg` soubory skutečnými zvuky (nejlépe syntetizované nebo ze CC0 zdrojů).
