# P16 — Hráčské profily (multi-user)

**Tier:** Opus 4.7 · **Wave:** 5 · **Deps:** P2 (DB + ProfilesDao), P5 (SettingsStore), P8a (Main Menu), P8b (Settings), P13 (Parent Dashboard).

## Scope

Plná podpora více hráčů na jednom zařízení (max 5 profilů). Hlavní motivy:

1. **Volba profilu při startu.** Pokud je v DB ≥ 1 profil a není zvolen aktivní, otevřít obrazovku „Vyber svého hráče". Pokud žádný profil neexistuje (čerstvá instalace), spustit kratší flow „Vytvoř první profil".
2. **Per-profilové nastavení.** Každý profil má vlastní SettingsStore data (délka kola, rychlost, povolené skilly, audio toggly, motiv). Stávající globální `user://settings.cfg` se rozdělí na `user://profiles/<id>/settings.cfg`.
3. **Per-profilové statistiky.** Stats scéna (`scenes/stats/stats.tscn`) zobrazí *pouze* data aktivního profilu. Dopočítat: odehraný čas, celkové skóre, **nejvyšší dosažené skóre v jednom kole**, průměrná chybovost (1 - accuracy), nejdelší správná série.
4. **Sekce „Potřebuje procvičit" a „Přehled dovedností".** Existují v `stats.tscn` jako prázdná místa (viz screenshot z 25. dubna). Buď doplnit reálnými daty z `StatsDao`, nebo odstranit. Tento WP je doplní (StatsDao už metody má — `skill_overview` + `skills_needing_practice`); pokud DB addon chybí, zobraz hlášku „Potřebuju SQLite addon, viz README".
5. **Definice a editace profilů.** Tlačítko „Profily" pod tlačítkem „Statistiky" otevře `scenes/profiles/profile_manager.tscn`: list profilů, tlačítko „Přidat" (až do 5), „Přejmenovat", „Smazat", „Vybrat jako aktivní".

**Mimo scope:** avatary (může být pozdější WP), cloud sync (DESIGN.md je explicitně offline-first).

## Files to create / modify

- `scripts/autoload/profile_service.gd` — **nový autoload**. Fasáda nad ProfilesDao + per-profile ConfigFile.
- `scripts/autoload/settings_store.gd` — **rozšířit** o awareness aktivního profilu (přepínat root path při změně profilu).
- `scenes/profiles/profile_picker.tscn` + `.gd` — počáteční volba profilu.
- `scenes/profiles/profile_manager.tscn` + `.gd` — CRUD obrazovka.
- `scenes/main_menu/main_menu.tscn` + `.gd` — přidat tlačítko „Profily" pod „Statistiky"; v `_ready()` zkontrolovat, zda je vybrán aktivní profil, a případně přesměrovat na picker.
- `scenes/stats/stats.gd` — doplnit chybějící totals (nejvyšší skóre, průměrná chybovost), zfunkčnit Potřebuje procvičit + Přehled dovedností přes `StatsDao`.
- `scripts/persistence/sessions_dao.gd` — přidat metodu `max_score_for_profile(db, profile_id) -> int`.
- `tests/unit/test_profile_service.gd` — kontraktové testy fasády.

## Veřejné API `ProfileService`

```gdscript
extends Node  # autoload

signal active_profile_changed(profile_id: int)
signal profile_list_changed                 ## emit po add/rename/delete

const MAX_PROFILES: int = 5

func list() -> Array                         ## Array[Dictionary] z ProfilesDao.get_all
func active_id() -> int                      ## 0 pokud žádný; jinak SettingsStore.get_value("profile/active_id")
func set_active(profile_id: int) -> bool     ## false pokud profil neexistuje; jinak emit signal
func create(name: String) -> int             ## vrací nové id; -1 při překročení MAX_PROFILES
func rename(profile_id: int, new_name: String) -> bool
func delete(profile_id: int) -> bool         ## CASCADE: smaže DB řádek + složku user://profiles/<id>/
func config_path_for(profile_id: int) -> String  ## "user://profiles/<id>/settings.cfg"
```

## SettingsStore změny

Stávající `const PATH := "user://settings.cfg"` zmizí — nahradí jej runtime computed path:

```gdscript
func _path_for_active_profile() -> String:
    var pid := ProfileService.active_id()
    if pid <= 0:
        return "user://settings.cfg"   # legacy fallback (pre-profile installs)
    return "user://profiles/%d/settings.cfg" % pid
```

Při emisi `ProfileService.active_profile_changed`: SettingsStore re-loaduje, emituje `settings_changed` pro každý klíč (aby UI aktualizovalo).

**Migrační krok:** při prvním startu po upgrade, pokud existuje legacy `user://settings.cfg` a žádný profil, vytvoř profil „Hráč 1" a přesuň config do `user://profiles/1/settings.cfg`. Idempotentní.

## Definition of Done

1. Čerstvá instalace → first-run picker → vytvoření profilu → aktivní profil je nastaven, settings flow funguje.
2. 2+ profily existují → po startu se zobrazí picker se seznamem; volba přepne aktivní profil.
3. Změna duration_s u profilu A se neprojeví u profilu B.
4. Stats scéna ukazuje data aktuálního profilu; přepnutí profilu → reload.
5. Stats scéna obsahuje nově: nejvyšší skóre v jednom kole + průměrnou chybovost.
6. „Potřebuje procvičit" + „Přehled dovedností" reálně zobrazují data; bez DB addon je placeholder ekvivalentní současnému empty state.
7. Profile Manager dovolí 5 profilů; 6. tlačítko „Přidat" je disabled.
8. Smazání aktivního profilu → automatické přepnutí na první zbývající; pokud žádný, redirect na picker.
9. Migrace ze stávajícího `user://settings.cfg` proběhne tichém transparentně.
10. `tests/unit/test_profile_service.gd` testuje create/rename/delete/active boundaries (in-memory DB).

## Otevřené otázky

_(vyplní agent)_

## Implementation log

- Nový autoload `ProfileService` (`scripts/autoload/profile_service.gd`) drží aktivní profil v `user://current_profile.cfg` (čte se před SettingsStore — proto je registrován hned za EventBus). DB-bound metody (`list/create/rename/delete`) všechny safely no-op když `DbGuard.writable(DB)` selže.
- `SettingsStore` přepsán: cesta k `settings.cfg` se odvozuje z `ProfileService.active_id()`, signály `active_profile_changed` triggerují reload + emise `settings_changed` pro každý DEFAULT klíč.
- Klíč `profile/active_id` z DEFAULTS odstraněn — autoritativní zdroj je teď `ProfileService.active_id()`. Všech 5 dříve-callerů (`main_menu`, `settings`, `game`, `stats`) přepojeno na ProfileService.
- `SessionsDao.max_score_for_profile(db, profile_id)` přidán (P16 spec).
- `StatsDao.profile_totals` rozšířena o `max_score`, `best_streak_overall`, `avg_error_rate` (jeden round-trip přes SQL agregace).
- Stats scéna zobrazuje 4 řádky totals (Sezení / Odehraný čas / Celkové skóre / Nejlepší kolo / Nejdelší série / Chybovost). Existující sekce „Potřebuje procvičit" + „Přehled dovedností" zůstávají beze změny — funkční už od P13, jen teď reálně dostávají data per-profil.
- 2 nové scény pod `scenes/profiles/`: `profile_picker.tscn` (first-run / re-pick), `profile_manager.tscn` (CRUD, Parent Gate-protected). Picker se umí přepnout do empty-state režimu (single LineEdit + tlačítko) když DB nemá žádný profil.
- Main Menu volá `ProfileService.ensure_ready()` v `_ready()`; když vrátí false, redirectne na picker. Tlačítko „Profily" pod „Statistiky" otevírá manager (přes Parent Gate).
- Migrace ze starého `user://settings.cfg` proběhne lazily v `ensure_ready()`: pokud DB má 1 profil + existuje legacy settings file → soubor se přesune do `user://profiles/<id>/settings.cfg` a legacy se smaže (idempotentní).
- Smazání aktivního profilu → ProfileService nastaví aktivní na první zbývající (nebo 0); manager scéna při zpětu detekuje 0 a redirectne na picker.
- Testy: `tests/unit/test_profile_service.gd` (8 testů — config_path_for, MAX_PROFILES kontrakt, defenzivní set_active/create branche), rozšířený `tests/unit/test_stats_dao.gd` (max_score, best_streak_overall, avg_error_rate, max_score_for_profile, ignorování unfinished sessions). Žádné DB-bound CRUD testy pro ProfileService — vyžadovaly by injektovatelnost DB; smoke ověření přes ručně manager scénu (DoD).

### Follow-up: dual-backend (DB + lokální ConfigFile)

První pokus volal pouze ProfilesDao a bez `godot-sqlite` addonu se nedalo vytvořit ani první profil (nahlášeno uživatelem). Doplněn lokální ConfigFile backend (`user://profiles_local.cfg` se sekcemi `profile.<id>` a klíči `name` + `created_at`):

- `_has_db()` (= `DbGuard.writable(DB)`) rozhoduje, který backend `list/create/rename/delete/_profile_exists` použije.
- Active id zůstává v `current_profile.cfg` (společný pro oba backendy).
- ID se v lokálním backendu nikdy nerecyklují (`_next_local_id` = `max + 1`), aby se per-profile dirs nikdy nemíchaly.
- `ensure_ready()` je teď agnostický — používá `list()` polymorficky a funguje bez DB.
- Test `test_create_rejects_when_db_is_closed` přejmenován na `test_create_uses_local_backend_when_db_is_closed` a invertován (čistí po sobě přes delete).
