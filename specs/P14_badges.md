# P14 — Badges / Unlocks / Progression

**Tier:** Sonnet 4.6 · **Wave:** 4 (polish) · **Deps:** P2, P10.

## Scope

Zavedení systému postupu (progression) pro odměňování hráče za dosažené milníky. Odznaky a odemčené vizuální skiny motivují k dalšímu hraní. Hodnocení probíhá po skončení kola a zobrazuje se na obrazovce s výsledky.

## Files to create / modify

- `scripts/game/unlock_system.gd` — Správa pravidel pro udělování odznaků (Autoload nebo instance v GameController).
- `scripts/persistence/unlocks_dao.gd` — (Už existuje v P2, ale bude využíváno pro čtení/zápis).
- `scenes/results/unlock_toast.tscn` — Vizualizace právě odemčených předmětů.
- **Úprava:** `scripts/game/game_controller.gd` — volání UnlockSystem na konci hry (`ENDING` stav).
- **Úprava:** `scenes/results/results.gd` — Zobrazení vizualizace odemčených věcí ze seznamu, který předal GameController.

## Požadavky

1. **Pravidla (Milestones):** Definovat několik základních pravidel.
   - Odznaky (Badges): "Série 10 bez chyby!", "10 odehraných her", "Mistr sčítání (rating > 1400 na všech add_*)".
   - Skiny (Skins): Odemknutí motivu "Vesmír" za 1000 nasbíraných bodů celkem, "Balónky" za odehrání 5 po sobě jdoucích dnů.
2. **Evaluace:** Na konci hry se zkontrolují všechny podmínky v `UnlockSystem`. Pokud je některá splněna a záznam ještě neexistuje v `UnlocksDao`, zaznamená se a vrátí se v poli zpět do GameControlleru.
3. **Prezentace:** Výsledková obrazovka iteruje předaný seznam odemčených věcí a pro každou postupně zobrazí vyskakovací `unlock_toast` se specifickou animací (nebo přidá položky do listu s oznámením).
4. **Integration s P12 (Themes):** Vybraná témata/skiny v `ThemeSelector` se musí kontrolovat vůči databázi odemčených, zda si je hráč může vůbec vybrat (nebo je pro něj vizuálně zamknout zámkem).

## Definition of Done

1. V databázi se v tabulce `unlocks` správně objevují nové záznamy po splnění milníků.
2. Po dohrání se na Result obrazovce objeví vizuální potvrzení odemčení ("Odemkl jsi: Téma Vesmír").
3. Nově odemčené téma se automaticky zpřístupní v nastavení hry (pokud P12 existuje).

## Otevřené otázky

- _Zatím žádné._
