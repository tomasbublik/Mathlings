# P22 — Settings: zvětšit a zvýraznit row „Zvuk a haptika"

**Tier:** Haiku 4.5 · **Wave:** 5 · **Deps:** P8b (Settings).

## Scope

V `scenes/settings/settings.tscn` má sekce `AudioRow` (CheckButton-y SFX, Hudba, Vibrace + náhledový button 🔊) tak malé písmo, že texty nejdou na mobilu přečíst, a hit area přepínačů je menší než minimálních 72 dp z DESIGN.md §2 (přístupnost). Cíl:

1. Zvětšit `font_size` štítků CheckButton-ů na `28` (matchuje sousední „Aktivní dovednosti").
2. Zvětšit `custom_minimum_size` na `Vector2(0, 80)` (= cca 80 dp výška, dotková plocha OK).
3. Přidat textový outline (černá `outline_size = 4`, `font_outline_color = Color(0,0,0)`) — stejně jako label „Aktivní dovednosti" a CheckBoxy ve `SkillsGrid`.
4. Náhledový tlačítko 🔊 zvětšit na `Vector2(80, 80)` (čtverec, ať palec lehce trefí).
5. Increase mezery v `AudioRow` (z `separation = 32` na `48`, případně přidat `theme_override_constants/h_separation` při použití `HFlowContainer`).

**Mimo scope:** přepracování celé Settings scény, nový theme resource (zatím dělané přes per-node theme_overrides).

## Files to create / modify

- `scenes/settings/settings.tscn` — pouze úpravy uzlu `AudioRow` a jeho dětí.
- `scenes/settings/settings.gd` — _žádná změna_.

## Konkrétní úpravy

```diff
 [node name="AudioRow" type="HFlowContainer" parent="ScrollContainer/VBox"]
-theme_override_constants/separation = 32
+theme_override_constants/h_separation = 48
+theme_override_constants/v_separation = 16

 [node name="SfxToggle" type="CheckButton" parent="ScrollContainer/VBox/AudioRow"]
 unique_name_in_owner = true
+custom_minimum_size = Vector2(0, 80)
+theme_override_colors/font_color = Color(1, 1, 1, 1)
+theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
+theme_override_constants/outline_size = 4
+theme_override_font_sizes/font_size = 28
 text = "SFX"

 [node name="SfxPreviewButton" type="Button" parent="ScrollContainer/VBox/AudioRow"]
 unique_name_in_owner = true
+custom_minimum_size = Vector2(80, 80)
+theme_override_font_sizes/font_size = 32
 text = "🔊"
```

Stejné theme_override pro `MusicToggle` a `HapticsToggle`.

## Definition of Done

1. Po načtení Settings na 1280×720 (a 720×1280 portrétně) jsou texty „SFX", „Hudba", „Vibrace" na první pohled čitelné (≥ 28pt s černým outlinem).
2. Hit area každého přepínače je ≥ 80×80 px → na fyzickém tabletu prst trefí spolehlivě.
3. Stávající chování (settings → ConfigFile → AudioManager) je zachováno; tato změna je čistě UI.
4. Žádné parser warningy (`godot --check-only`).

## Otevřené otázky

_(žádné očekávané — čistě kosmetická úprava)_

## Implementation log

- Upraveny tři CheckButton uzly (SfxToggle, MusicToggle, HapticsToggle): `custom_minimum_size = Vector2(0, 80)` pro 80 dp výšku, `font_size = 28`, černý outline `outline_size = 4`.
- SfxPreviewButton 🔊 zvětšen na čtverec 80×80 px, font 32 (kvůli emoji).
- AudioRow používá `h_separation = 48` + `v_separation = 16` (HFlowContainer wrappuje na úzkých displayích sám).
- `settings.gd` zůstává beze změny — všechny změny jsou čistě v .tscn.
