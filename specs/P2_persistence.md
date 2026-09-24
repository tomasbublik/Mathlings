# P2 — Persistence (SQLite + DAO)

**Tier:** Sonnet 4.6 · **Wave:** 1 (paralelní) · **Deps:** žádné (DESIGN §6.1)

## Scope

- Instalace addonu [`godot-sqlite`](https://github.com/2shady4u/godot-sqlite) do `addons/godot-sqlite/`.
- Schema migrations v1 (přesně podle DESIGN §6.1).
- DAO třídy pro každou tabulku.
- Bootstrap schématu při prvním spuštění.
- Implementace autoloadu `DB` (dosud stub v `scripts/autoload/db.gd`).

**Mimo scope:** žádná UI, žádná business logika (Elo patří do P9).

## Files to create / modify

- `addons/godot-sqlite/` — zkopírovat stabilní release addonu (v4.3+ kompatibilní).
- `scripts/persistence/schema.sql` — DDL podle DESIGN §6.1 + `meta` tabulka.
- `scripts/persistence/migrations.gd` — `class_name Migrations`. `run(db)` → aplikuje chybějící migrace.
- `scripts/persistence/profiles_dao.gd`
- `scripts/persistence/skills_dao.gd`
- `scripts/persistence/sessions_dao.gd`
- `scripts/persistence/attempts_dao.gd`
- `scripts/persistence/unlocks_dao.gd`
- `scripts/autoload/db.gd` — **úprava** stubu na plnou implementaci.
- `tests/unit/test_daos.gd` — GUT.

> `project.godot` autoload `DB` už existuje — **neupravuj `project.godot`**, jen implementuj metody.

## Veřejné API autoloadu `DB`

```gdscript
extends Node
## Otevře (nebo vytvoří) databázi v user://mathlings.db a aplikuje migrace.
func open() -> void
func close() -> void

## Transakční helper.
func transaction(body: Callable) -> void

## Raw exec; vrací Array[Dictionary] (rows).
func execute(sql: String, params: Array = []) -> Array
```

## DAO API (vzor)

```gdscript
class_name AttemptsDao

static func insert(
    db,
    session_id: int,
    skill_key: String,
    expression: String,
    correct_answer: int,
    choices: Array[int],
    chosen_index: int,        # -1 pokud minul
    correct: bool,
    reaction_ms: int,         # -1 pokud minul
    shown_at_ms: int,
    resolved_at_ms: int
) -> int  ## vrací id

static func for_session(db, session_id: int) -> Array[Dictionary]
static func count_by_skill(db, profile_id: int) -> Dictionary  ## {skill_key: int}
```

Analogicky pro další DAO (viz DESIGN §6.1 sloupce).

## Požadavky

1. DB soubor: `user://mathlings.db`. Na desktopu Godotu typicky `~/Library/Application Support/Godot/app_userdata/Mathlings/mathlings.db`.
2. `meta.schema_version` = `"1"` po migraci v1.
3. Všechna časová pole = **unix milliseconds** (`Time.get_unix_time_from_system() * 1000` přetypováno na int).
4. Foreign keys zapnuté: `PRAGMA foreign_keys = ON;` po otevření.
5. Na první spuštění vlož jeden default profile `(id=1, name="Hráč 1", created_at=now_ms)` přes `ProfilesDao`.
6. `transaction()` rollbackuje, pokud `body` hodí chybu / vrátí `false`.

## Testy

- `test_migrations`: fresh in-memory DB → `Migrations.run()` → schema_version == "1", všechny tabulky existují.
- Pro každé DAO insert + fetch round-trip.
- `test_foreign_keys`: insert attempt s neexistujícím session_id musí selhat.
- `test_default_profile`: fresh DB má přesně 1 profile.

## Definition of Done

Společné + DB se otevírá v dev modu v Godotu, vytvoří se soubor, `meta` má `schema_version=1`, default profile existuje, GUT testy zelené.

## Otevřené otázky

1. **Addon godot-sqlite**: Při generování kódu nebyl dostupný internet, proto addon NENÍ stažen.
   Viz `addons/godot-sqlite/PLACEHOLDER.md` s návodem k ruční instalaci (doporučena v3.8.0+).
   Testy jsou napsány, ale bez addonu nepoběží — při spuštění budou přeskočeny s `pending()`.

2. **Migrace rollback**: Migrations.run() nemá explicitní transakci kolem migrace v1 (každá tabulka je zvláštní query).
   Pro produkci by bylo lepší zabalit celou migraci do BEGIN/COMMIT. Ponecháno jako zjednodušení pro MVP.

3. **Cascade delete**: Při smazání profilu SQLite FK nesmažou automaticky navázané rows v skills/sessions/attempts/unlocks.
   Pokud bude potřeba cascade, přidej `ON DELETE CASCADE` do FK definic v migraci v2.

## Implementation log

Implementace proběhla v jednom průchodu (Wave 1, P2):

- `addons/godot-sqlite/PLACEHOLDER.md` — addon nebyl stažen (offline); placeholder s návodem.
- `scripts/persistence/schema.sql` — DDL pro všechny tabulky dle DESIGN §6.1 + `meta` tabulka se seed řádkem `schema_version='1'`; všechny CREATE jsou `IF NOT EXISTS`.
- `scripts/persistence/migrations.gd` — třída `Migrations` se statickou metodou `run(db: SQLite)`. Čte aktuální verzi z `meta`, aplikuje pouze chybějící migrace; idempotentní.
- `scripts/persistence/profiles_dao.gd` — CRUD pro tabulku `profiles`; `ensure_default()` vloží "Hráč 1" pokud je DB prázdná.
- `scripts/persistence/skills_dao.gd` — UPSERT, `get_or_create`, `record_attempt` pro Elo záznamy.
- `scripts/persistence/sessions_dao.gd` — `insert` (start kola) + `close_session` (end kola se statistikami).
- `scripts/persistence/attempts_dao.gd` — `insert` (chosen_index/reaction_ms = null při miss), `for_session`, `count_by_skill`.
- `scripts/persistence/unlocks_dao.gd` — `INSERT OR IGNORE` pro idempotentní odemknutí, `is_unlocked`, `get_by_kind`.
- `scripts/autoload/db.gd` — plná implementace: `open()` (otevře DB, FK ON, Migrations.run(), ProfilesDao.ensure_default), `close()`, `execute()` (query_with_bindings), `transaction()` (BEGIN/COMMIT/ROLLBACK). Bezpečně selže s `push_error` pokud addon chybí.
- `tests/unit/test_daos.gd` — GUT testy: `test_migrations_*`, `test_default_profile_*`, round-trip pro každé DAO, `test_foreign_keys_attempt_invalid_session`. Testy gracefully skipují pokud addon není nainstalován.
