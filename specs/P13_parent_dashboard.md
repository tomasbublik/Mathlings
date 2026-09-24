# P13 — Parent Dashboard + Stats

**Tier:** Sonnet 4.6 · **Wave:** 4 (polish) · **Deps:** P2, P8a.

## Scope

Vytvoření podrobného dashboardu pro rodiče. Tento dashboard se otevře po úspěšném vyřešení `ParentGate` (P8a) z hlavního menu. Slouží pro zobrazení historických dat a identifikaci problematických oblastí dítěte.

## Files to create / modify

- `scenes/stats/stats.tscn` — UI scéna s dashboardem.
- `scenes/stats/stats.gd` — Načítání a formátování dat do UI.
- `scripts/persistence/stats_dao.gd` — DAO pomocník pro agregační dotazy (nebo přidat metody do existujících DAO).

## Požadavky

1. **Dashboard UI:** Rozvržení by mělo obsahovat:
   - Celkový odehraný čas a počet sezení (načteno ze `SessionsDao`).
   - Přehled dovedností: Tabulka/seznam se sloupci Dovednost, Rating, Přesnost (correct/attempts).
   - "Potřebuje procvičit": Zvláštní panel s top 3 dovednostmi, kde má dítě nejmenší přesnost nebo nedávno udělalo hodně chyb (data z `AttemptsDao` / `SkillsDao`).
2. **Přístup:** Kliknutí na "Statistiky" v hlavním menu již vyvolává `ParentGate`. V `main_menu.gd` je nutné nahradit placeholder pro zobrazení toastu "Brzy!" za reálné načtení `stats.tscn`.
3. **Agregace dat:** SQL dotazy pro spočítání úspěšnosti konkrétních příkladů (např. které konkrétní číslo z násobilky dělá největší problém).

## Definition of Done

1. Ve "Statistikách" se správně zobrazují agregovaná data o hráči.
2. Tabulka dovedností filtruje a řadí data logicky (např. dle ratingu vzestupně, aby se slabiny ukázaly nahoře).
3. Dotazy na databázi neblokují UI (na velkém objemu dat). Pro účely MVP stačí načíst data synchronně při inicializaci scény s případným loading indikátorem.

## Otevřené otázky

- _Zatím žádné._
