class_name Migrations
## Správa migrací schématu databáze Mathlings.
## Aplikuje pouze chybějící migrace; volání je idempotentní.
## Použití: Migrations.run(db_instance)

## Číslo aktuální verze schématu.
const CURRENT_VERSION: int = 1


## Spustí všechny chybějící migrace na předané instanci SQLite (godot-sqlite SQLite objekt).
## Parametr db je Object (ne SQLite) aby nevyžadoval addon při parsování.
## Po dokončení je meta.schema_version == CURRENT_VERSION.
static func run(db: Object) -> void:
	_ensure_meta_table(db)
	var version: int = _get_version(db)
	if version < 1:
		_migrate_v1(db)


## Vrátí aktuální schema_version z meta tabulky, nebo 0 pokud tabulka/řádek neexistuje.
static func _get_version(db: Object) -> int:
	var rows: Array = db.select_rows("meta", "key = 'schema_version'", ["value"])
	if rows.is_empty():
		return 0
	var val: String = str(rows[0].get("value", "0"))
	return int(val)


## Vytvoří tabulku meta, pokud ještě neexistuje.
static func _ensure_meta_table(db: Object) -> void:
	db.query("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);")


## Migrace v1 — vytvoří celé základní schema přesně dle DESIGN §6.1.
static func _migrate_v1(db: Object) -> void:
	# profiles
	db.query("""
		CREATE TABLE IF NOT EXISTS profiles (
			id         INTEGER PRIMARY KEY,
			name       TEXT    NOT NULL,
			avatar_key TEXT,
			created_at INTEGER NOT NULL
		);
	""")

	# skills
	db.query("""
		CREATE TABLE IF NOT EXISTS skills (
			profile_id   INTEGER NOT NULL,
			skill_key    TEXT    NOT NULL,
			rating       REAL    NOT NULL DEFAULT 1000.0,
			attempts     INTEGER NOT NULL DEFAULT 0,
			correct      INTEGER NOT NULL DEFAULT 0,
			last_seen_at INTEGER,
			PRIMARY KEY (profile_id, skill_key),
			FOREIGN KEY (profile_id) REFERENCES profiles(id)
		);
	""")

	# sessions
	db.query("""
		CREATE TABLE IF NOT EXISTS sessions (
			id          INTEGER PRIMARY KEY,
			profile_id  INTEGER NOT NULL,
			started_at  INTEGER NOT NULL,
			ended_at    INTEGER,
			duration_ms INTEGER,
			score       INTEGER NOT NULL DEFAULT 0,
			best_streak INTEGER NOT NULL DEFAULT 0,
			accuracy    REAL,
			config_json TEXT    NOT NULL,
			FOREIGN KEY (profile_id) REFERENCES profiles(id)
		);
	""")

	# attempts
	db.query("""
		CREATE TABLE IF NOT EXISTS attempts (
			id             INTEGER PRIMARY KEY,
			session_id     INTEGER NOT NULL,
			skill_key      TEXT    NOT NULL,
			expression     TEXT    NOT NULL,
			correct_answer INTEGER NOT NULL,
			choices_json   TEXT    NOT NULL,
			chosen_index   INTEGER,
			correct        INTEGER NOT NULL,
			reaction_ms    INTEGER,
			shown_at       INTEGER NOT NULL,
			resolved_at    INTEGER NOT NULL,
			FOREIGN KEY (session_id) REFERENCES sessions(id)
		);
	""")

	# unlocks
	db.query("""
		CREATE TABLE IF NOT EXISTS unlocks (
			profile_id  INTEGER NOT NULL,
			kind        TEXT    NOT NULL,
			key         TEXT    NOT NULL,
			unlocked_at INTEGER NOT NULL,
			PRIMARY KEY (profile_id, kind, key),
			FOREIGN KEY (profile_id) REFERENCES profiles(id)
		);
	""")

	# indexy
	db.query("CREATE INDEX IF NOT EXISTS idx_attempts_session ON attempts(session_id);")
	db.query("CREATE INDEX IF NOT EXISTS idx_attempts_skill   ON attempts(skill_key);")
	db.query("CREATE INDEX IF NOT EXISTS idx_sessions_profile ON sessions(profile_id, started_at);")

	# zapiš verzi
	db.query("INSERT OR REPLACE INTO meta (key, value) VALUES ('schema_version', '1');")
