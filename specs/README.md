# Work Packages — Mathlings

Každý soubor `Pxx_*.md` je samostatný work package (WP) připravený tak, aby ho mohl zpracovat **jeden subagent v jednom sezení** bez nutnosti číst ostatní WP. WP zná:
- Rozsah (co dělá, co NEdělá).
- Závislosti (které WP musí být hotové předem + které kontrakty v `DESIGN.md` používá).
- Přesný seznam souborů, které má vytvořit.
- Veřejné API a přesné chování.
- Definition of Done a testovací nároky.
- Doporučený modelový tier a odhad složitosti.

**Autoritativní je `DESIGN.md`** (zejména §7 Sdílené kontrakty). Pokud je WP v rozporu, platí DESIGN a WP je potřeba opravit.

---

## Vlny a závislosti

```
Wave 0 (serial, foundation):
  F0  Project skeleton           ← HOTOVO (tento commit)

Wave 1 (plně paralelní, žádné závislosti mezi sebou):
  P1  Problem Generator          ┐
  P2  Persistence (SQLite + DAO) ├── všechny čtou pouze DESIGN.md
  P3  Audio Manager              │   §6 (data), §7 (kontrakty)
  P4  Haptics Manager            │
  P5  Settings Store             │
  P6  Placeholder Assets         ┘

Wave 2 (paralelní po Wave 1):
  P7  Falling Problem (entita)   ← vyžaduje Problem kontrakt (P1)
  P8a Main Menu scéna            ← vyžaduje SettingsStore (P5)
  P8b Settings scéna             ← vyžaduje SettingsStore (P5)
  P8c Results scéna              ← vyžaduje DAO (P2)
  P9  Skill Model (Elo)          ← vyžaduje DAO (P2)

Wave 3 (serial, orchestrace):
  P10 Game Controller            ← spojuje vše

Wave 4 (polish, paralelně po P10):
  P11 Particle efekty + VFX
  P12 Themes + skiny (art pass)
  P13 Parent dashboard + stats
  P14 Badges / unlocks / progression
  P15 Android export + podpis

Wave 5 (next-gen features, většinou paralelně):
  P16 Hráčské profily (multi-user)         ← vyžaduje P2, P5, P8a/b, P13
  P17 Externalizovaná pravidla skóre + UI  ← vyžaduje P10
  P18 i18n + výběr jazyka                  ← dotýká se všech UI scén
  P19 Šťavnaté ovoce explosion             ← vyžaduje P7, P11, P12
  P20 Vesmírný motiv polish (SFX + VFX)    ← vyžaduje P3, P11, P12, ideálně po P19
  P21 Verze v Main Menu                    ← vyžaduje P8a
  P22 Settings audio row UI fix            ← vyžaduje P8b
```

## Modelový tier matrix

| WP | Tier | Důvod |
|---|---|---|
| P1 Problem Generator | **Sonnet 4.6** | Čistá logika, testovatelná, střední složitost |
| P2 Persistence | **Sonnet 4.6** | Schema + DAO vzory, well-understood |
| P3 Audio Manager | **Haiku 4.5** | Mapování klíč→AudioStreamPlayer, triviální |
| P4 Haptics | **Haiku 4.5** | Wrapper nad `Input.vibrate_handheld()`, triviální |
| P5 Settings Store | **Haiku 4.5** | Wrapper nad `ConfigFile`, mechanický |
| P6 Placeholder Assets | **Haiku 4.5** | Generování CC0/SVG placeholderů |
| P7 Falling Problem | **Sonnet 4.6** | Node hierarchy + animace, střední |
| P8a Main Menu | **Sonnet 4.6** | UI scéna + routing |
| P8b Settings scéna | **Sonnet 4.6** | Formulář, střední, hodně kontrol |
| P8c Results scéna | **Sonnet 4.6** | UI + dotaz na DAO |
| P9 Skill Model (Elo) | **Opus 4.7** | Algoritmus, edge cases, tuning, kritické |
| P10 Game Controller | **Opus 4.7** | Orchestrace, state machine, race conditions |
| P11 VFX | **Sonnet 4.6** | Particle systémy, polish |
| P12 Themes | **Sonnet 4.6** | Art pass + theme switcher |
| P13 Parent dashboard | **Sonnet 4.6** | UI + agregační dotazy |
| P14 Badges | **Sonnet 4.6** | Pravidla + UI |
| P15 Android export | **Sonnet 4.6** | Konfigurace, méně kódu |
| P16 Profiles | **Opus 4.7** | Migrace per-profile settings, state machine, dotahuje stats |
| P17 External rules | **Sonnet 4.6** | Loader + formátování textu, low risk |
| P18 i18n | **Opus 4.7** | Plošná extrakce stringů + RTL + 12 lokalizací |
| P19 Fruit VFX | **Sonnet 4.6** | Particle ladění + 9 nových SVG ovocí |
| P20 Space polish | **Sonnet 4.6** | SFX chain + nové skiny, výrazově náročnější |
| P21 Version display | **Haiku 4.5** | Triviální Label + dokumentace |
| P22 Settings UI fix | **Haiku 4.5** | Pouze tscn úpravy |

> **Pravidlo palce:** Haiku pro "napiš mi tuhle konkrétní drobnost přesně podle vzoru", Sonnet pro "implementuj tuhle komponentu podle specifikace", Opus pro "tohle vyžaduje úsudek, algoritmus nebo orchestraci více věcí".

## Definition of Done (společné pro všechny WP)

1. Soubory existují přesně na cestách uvedených ve WP.
2. Projekt se otevře v Godotu 4.3+ bez chyb v editoru.
3. Žádné parser warnings (`--check-only`).
4. Unit testy (pokud WP je vyžaduje) procházejí přes GUT.
5. Dokumentační komentář `##` na každé veřejné funkci/třídě.
6. Static typing všude, kde GDScript dovolí.
7. Žádné změny v souborech mimo scope WP (vyjma explicitně povolených).
8. Žádné nové autoloady bez aktualizace `project.godot` A zápisu do `DESIGN.md §7.3`.
9. `git status` je čistý kromě souborů ve scope.

## Jak spustit WP subagentem

Typický prompt pro subagenta:

> Pracuj v kořeni repozitáře. Přečti `DESIGN.md` (celé, je to bible projektu) a pak `specs/P3_audio_manager.md` (tvůj WP). Implementuj přesně podle specifikace, nic navíc. Dodrž Definition of Done z `specs/README.md`. Když narazíš na nejasnost v kontraktu, **nehádej** - zapiš otázku do sekce "Otevřené otázky" ve WP a skonči s popisem, co ti chybí. Nepouštěj se do jiných WP.

## Pravidla pro subagenty (MUSÍ)

- **Nikdy** neměň `DESIGN.md §7` (sdílené kontrakty). Pokud je to nutné, skonči a řekni to.
- **Nikdy** neměň `project.godot` s výjimkou registrace autoloadu, který tvůj WP přidává.
- **Nikdy** nevytvářej dokumentaci (extra `.md`) mimo svůj WP.
- Soubory, které nejsou ve "Files to create" seznamu WP, neupravuj.
- Pokud potřebuješ sdílený helper, **nepřidávej ho** - požádej o doplnění kontraktu v DESIGN.
- Na konci přidej do svého WP sekci **"Implementation log"** s krátkým popisem, co jsi udělal a proč.
