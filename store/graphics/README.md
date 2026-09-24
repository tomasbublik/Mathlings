# Google Play graphics — Mathlings

Everything the Play Console "Main store listing → Graphics" section needs.
All PNGs are 24-bit RGB (no alpha) unless noted; all sizes are within Play's
limits (each side 320–3840 px, aspect ratio ≤ 2:1).

| File | Size | Play Console slot |
|---|---|---|
| `icon_512.png` | 512×512, 32-bit PNG (fully opaque) | **App icon** |
| `feature_graphic_1024x500.png` | 1024×500 | **Feature graphic** |
| `phone/01_menu.png` … `07_party.png` | 2400×1080 (20:9) | **Phone screenshots** (English / default listing) |
| `phone_cs/01_menu.png` … `07_party.png` | 2400×1080 | **Phone screenshots** of the Czech (cs-CZ) listing |
| `tablet7/01_menu.png` … `04_stats.png` | 1920×1200 (16:10) | **7-inch tablet screenshots** |
| `tablet10/01_menu.png` … `04_stats.png` | 2560×1600 (16:10) | **10-inch tablet screenshots** |
| `phone_framed/01_menu.png` … `07_party.png` | 2400×1080 | Optional alternative phone set: the English screenshots on a grape background with a caption |

## Screenshot story (phone)

1. `01_menu` — main menu with the Mathling mascot and the Play button.
2. `02_gameplay` — mid-round: a falling sum, three colourful answer buttons, streak + ×1.5 combo sticker.
3. `03_burst` — the moment a correct answer pops the fruit (+15 ×1.5 points, mint flash).
4. `04_results` — results: 3 stars, cheering mascot, accuracy and best streak, confetti
   and the "New reward!" card (10 in a row, no mistakes).
5. `05_stats` — "My progress" scrolled to "Let's practise these" and the "My skills"
   bars (two skills mastered, two in progress; tablets show a third mastered skill).
6. `06_space` — the space theme.
7. `07_party` — the party theme (balloons float up).

Play accepts up to 8 phone screenshots; drop 07 if you prefer the 6-shot story.

Tablets (7" and 10") use the same key screens: menu, gameplay, results, progress.
The Czech set (`phone_cs/`) has the same story (results with the "Nová odměna!" card).

All screenshots are real, unedited frames of the game (profile names "Mia" / "Ema"
are neutral example names; the play history and per-skill numbers on the progress
screen were seeded).

## Regenerating

### Icon
`icon_512.png` is a copy of `assets/store/icon_512.png` (generator:
`tools/mascot/gen_icon.py`). After regenerating the icon, copy it again:

```sh
cp assets/store/icon_512.png store/graphics/icon_512.png
```

### Feature graphic
Artwork (sky, sunburst, mascot, maths candy, fruit) is an SVG composed by a
Python script that reuses the mascot generator; the "Mathlings" wordmark is
drawn by Godot in Baloo 2 in the HeroLabel sticker style (white, GRAPE_DARK
outline, soft shadow). Rendered at 2× and downsampled.

```sh
python3 tools/store/gen_feature_graphic.py                          # -> tools/store/feature_graphic_art.svg
godot --path . --script res://tools/store/render_feature_graphic.gd # -> store/graphics/feature_graphic_1024x500.png
```

(Not `--headless`: the title needs a renderer. The window closes by itself.)
Title position/size: constants at the top of `render_feature_graphic.gd`.
The only text is the logo word, so the graphic works for every locale.

### Framed phone screenshots
Captions are in `tools/store/framed_captions.json` (one block per locale, keyed
by screenshot file name) so they can be translated later.

```sh
godot --path . --script res://tools/store/render_framed.gd                 # en: phone/ -> phone_framed/
godot --path . --script res://tools/store/render_framed.gd -- --locale cs  # needs a "cs" block: phone_cs/ -> phone_framed_cs/
```

### Screenshots
Captured from the running game with a throwaway harness (not committed, by
design) that ran against a scratch copy of the project with an `override.cfg`
(`application/config/use_custom_user_dir=true` + an extra autoload), so the
desktop user data of the real project was never touched. Per run it:

1. creates a profile ("Mia" for en, "Ema" for cs) via `ProfileService`, sets the
   locale, turns sound off, sets the round length to 5 min (a real Settings
   option, so there are enough problems to find a clean burst frame; restored
   to 2 min afterwards) and the enabled skills (add/sub to 20, ×2, ×5; tablets
   also ×10); seeds six earlier 2-minute rounds on six earlier days into both
   `SessionStatsStore.record_session` (stat tiles) and
   `ProgressStore.record_round` (round history), and unlocks the space and
   party themes on earlier days (`ProgressStore.unlock`) so the results screen
   shows only the streak reward;
2. seeds per-skill aggregates with `ProgressStore.set_skill` (+ `flush`):
   add to 20 61/64, ×2 47/51, (×10 44/46), subtraction to 20 41/56, ×5 26/38;
3. opens the main menu (blanks the "+debug" version label) and captures it;
4. starts `game.tscn` with the fruit theme and answers through the scene's own
   answer handler (`_on_answer_pressed` with the controller's `correct_index`)
   until a ×1.5 combo is running; trivial problems (an operand 0/1, result < 3)
   are answered and skipped so the captured problem is meaningful; captures the
   falling problem, then keeps answering until the next spawned problem shows
   the previous answer on the same button (mint "correct" button matches the
   exploding sum) and captures the burst; the rest of the round is
   fast-forwarded with `Engine.time_scale`, one answer in fourteen wrong
   (best streak ≥ 10, so the "10 in a row" reward card appears);
5. captures the results screen ~1.9 s in (stars landed, confetti falling);
   re-applies the seeded skill numbers (the real round also updates them),
   opens "My progress" and scrolls it to the end (practice + skills cards);
   then a space-theme and a party-theme round; a round paused by the desktop
   window losing focus is resumed automatically;
6. converts every frame to RGB8 and saves it.

Resolutions: `godot --path . --resolution 2400x1080` (phone),
`1920x1200` (7"), `2560x1600` (10"). Tablet files are the phone story's
01/02/04/05 frames, renumbered 01–04.

Total size of all PNGs in this folder: about 7 MB (PNG as rendered, no lossy compression).
