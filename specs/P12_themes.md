# P12 — Themes + skiny (Art pass)

**Tier:** Sonnet 4.6 · **Wave:** 4 (polish) · **Deps:** P5, P6, P10.

## Scope

Zavedení dynamické změny vizuálního tématu hry (pozadí, skiny padajících příkladů). Umožnit hráči vybrat si preferované téma z odemčených (uloženo v profilu/settings).

## Files to create / modify

- `scripts/autoload/theme_manager.gd` — Autoload pro správu aktuálního tématu.
- `scenes/settings/theme_selector.tscn` — UI komponenta pro výběr tématu.
- **Úprava:** `scenes/settings/settings.tscn` — přidání záložky/sekce pro "Vzhled".
- **Úprava:** `scenes/game/game.gd` — inicializace s vybraným tématem.
- **Úprava:** `scripts/autoload/settings_store.gd` — uložení vybraného motivu.

## Požadavky

1. **Theme Katalog:** `ThemeManager` musí znát seznam dostupných témat (např. "Ovoce", "Vesmír", "Balónky"). Každé téma definuje cestu k textuře pro pozadí (`bg_sky.svg`, `bg_space.svg`) a skin padající entity (`skin_apple.svg`, `skin_meteor.svg`, `skin_balloon.svg`).
2. **SettingsStore podpora:** Rozšíření defaultního configu o klíč `appearance/theme` (výchozí: "Ovoce").
3. **Předávání do Entity:** `GameController` nebo herní scéna přečte aktivní skin a při volání `FallingProblem.setup(...)` ho předá k vykreslení. Pozadí se nastaví na příslušný `.svg` soubor.
4. **Theme Selector:** V Settings scéně jednoduchý horizontální `ItemList` nebo sada tlačítek s ikonami pro přepínání. Vybrané téma by se mělo rovnou projevit i na pozadí samotného menu.

## Definition of Done

1. V nastavení je vidět volba motivu (Ovoce, Vesmír, Balónky).
2. Po změně motivu se ihned aktualizuje pozadí.
3. Spuštění hry s motivem Vesmír používá tmavé pozadí a padající meteory místo jablek.
4. Volba je persistentní mezi restarty aplikace.

## Otevřené otázky

- _Zatím žádné._
