# P8b — Settings scéna

**Tier:** Sonnet 4.6 · **Wave:** 2 · **Deps:** P5 (SettingsStore).

## Scope

Obrazovka nastavení. Přes `ParentGate` (implementováno v P8a) pouze. Všechny hodnoty čte a zapisuje přes `SettingsStore`.

## Files to create

- `scenes/settings/settings.tscn`
- `scenes/settings/settings.gd`

## Sekce UI

1. **Kolo**
   - Délka kola: radio group `30 / 60 / 120 / 180 / 300 s`.
   - Rychlost pádu: radio group `pomalu / normálně / rychle / adaptivní`.
2. **Aktivní dovednosti**
   - Group checkboxů podle `ProblemGenerator.supported_skills()` (viz P1). Label = česky (viz slovník níže).
3. **Zvuk a haptika**
   - Toggle: SFX, Hudba, Vibrace.
4. **Profil**
   - Aktivní profil (dropdown z DB profiles, pokud DB dostupné; jinak jen "Hráč 1" disabled).
5. **Tlačítka**
   - "Zpět" (návrat na MainMenu), "Obnovit výchozí" (s potvrzením).

## Slovník skill_key → label cs_CZ

| Key | Label |
|---|---|
| `add_0_10` | Sčítání do 10 |
| `add_0_20` | Sčítání do 20 |
| `add_0_100` | Sčítání do 100 |
| `sub_0_10` | Odčítání do 10 |
| `sub_0_20` | Odčítání do 20 |
| `sub_0_100` | Odčítání do 100 |
| `mul_x2` … `mul_x10` | Násobilka × k |
| `div_0_100` | Dělení do 100 |

Uchovej mapu v `scripts/ui/skill_labels.gd` (const `LABELS: Dictionary`).

## Chování

1. Při `_ready` načti všechny hodnoty ze `SettingsStore` a populuj UI.
2. Každá změna UI ihned volá `SettingsStore.set_value(key, value)`.
3. "Obnovit výchozí" → dialog "Opravdu?" → `SettingsStore.reset_to_defaults()` → reload UI.
4. Validace: alespoň 1 dovednost musí být povolena; pokud uživatel odškrtne poslední, vrať checkbox s krátkou hláškou.
5. `AudioManager.play_sfx("correct")` hraje jen jako preview, pokud user klikne ikonku ucha vedle SFX toggle.

## Testy

Manuální - změna hodnoty se projeví v `user://settings.cfg` po re-openu scény.

## Definition of Done

Společné + všechny hodnoty podle DESIGN §6.3 jsou v UI editovatelné; restart aplikace uchová změny.

## Otevřené otázky

_(vyplní agent)_

## Implementation log

- `SkillLabels` (class_name v `scripts/ui/skill_labels.gd`) obsahuje kanonickou cs_CZ mapu.
- Duration/speed jsou implementovány jako toggle Buttony ve `HBoxContainer` (radio chování se řeší ručně — všechny ostatní se odškrtnou).
- Validace: odškrtnutí poslední aktivní dovednosti je zablokováno (`set_pressed_no_signal(true)` + flash `ValidationLabel`).
- "Obnovit výchozí" používá dynamický `ConfirmationDialog`, po potvrzení volá `SettingsStore.reset_to_defaults()` a znovu načte UI.
