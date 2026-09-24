extends GutTest
## GUT testy pro persistence vrstvu (P2).
## Testy používají in-memory SQLite databázi (:memory:) — nevyžadují soubor na disku.
## POZOR: testy vyžadují nainstalovaný addon godot-sqlite.
##        Pokud addon chybí, testy budou přeskočeny s varováním.

## Pomocná třída simulující DB autoload pro DAO testy.
## Obaluje SQLite instanci ve stejném API jako autoload DB.
class InMemoryDB:
	var _db: Object = null
	var _is_open: bool = false

	## Otevře in-memory SQLite a aplikuje migrace v1.
	func open() -> bool:
		if not ClassDB.class_exists("SQLite"):
			return false
		_db = SQLite.new()
		_db.path = ":memory:"
		_db.verbosity_level = SQLite.QUIET
		if not _db.open_db():
			return false
		_is_open = true
		_db.query("PRAGMA foreign_keys = ON;")
		Migrations.run(_db as Object)
		return true

	func close() -> void:
		if _is_open:
			_db.close_db()
			_db = null
			_is_open = false

	## Stejné API jako DB.execute().
	func execute(sql: String, params: Array = []) -> Array:
		if not _is_open:
			return []
		if params.is_empty():
			_db.query(sql)
		else:
			_db.query_with_bindings(sql, params)
		return (_db.get("query_result") as Array).duplicate(true)

	## Stejné API jako DB.transaction().
	func transaction(body: Callable) -> void:
		if not _is_open:
			return
		_db.query("BEGIN;")
		var ok = body.call()
		if ok == null:
			ok = true
		if ok:
			_db.query("COMMIT;")
		else:
			_db.query("ROLLBACK;")


var _mem_db: InMemoryDB = null


func before_each() -> void:
	_mem_db = InMemoryDB.new()
	if not _mem_db.open():
		_mem_db = null
		gut.p("SKIP: godot-sqlite addon není dostupný. Nainstaluj addon dle addons/godot-sqlite/PLACEHOLDER.md.")


func after_each() -> void:
	if _mem_db != null:
		_mem_db.close()
		_mem_db = null


## Přeskočí test pokud addon není dostupný.
func _skip_if_no_db() -> bool:
	if _mem_db == null:
		pending("godot-sqlite addon není dostupný")
		return true
	return false


# ---------------------------------------------------------------------------
# test_migrations
# ---------------------------------------------------------------------------

## Ověří, že po Migrations.run() existuje schema_version = "1".
func test_migrations_schema_version() -> void:
	if _skip_if_no_db():
		return
	var rows: Array = _mem_db.execute("SELECT value FROM meta WHERE key = 'schema_version';")
	assert_eq(rows.size(), 1, "meta tabulka musí mít řádek schema_version")
	assert_eq(str(rows[0].get("value", "")), "1", "schema_version musí být '1'")


## Ověří, že všechny tabulky existují po migraci.
func test_migrations_all_tables_exist() -> void:
	if _skip_if_no_db():
		return
	var tables: Array = ["profiles", "skills", "sessions", "attempts", "unlocks", "meta"]
	for tbl in tables:
		var rows: Array = _mem_db.execute(
			"SELECT name FROM sqlite_master WHERE type='table' AND name=?;", [tbl]
		)
		assert_eq(rows.size(), 1, "tabulka '%s' musí existovat" % tbl)


## Ověří idempotenci: opakované spuštění Migrations.run() nesmí selhat.
func test_migrations_idempotent() -> void:
	if _skip_if_no_db():
		return
	# Druhé spuštění — nesmí vyvolat chybu
	Migrations.run(_mem_db._db)
	var rows: Array = _mem_db.execute("SELECT value FROM meta WHERE key = 'schema_version';")
	assert_eq(str(rows[0].get("value", "")), "1", "schema_version po druhé migraci musí být stále '1'")


# ---------------------------------------------------------------------------
# test_default_profile
# ---------------------------------------------------------------------------

## Ověří, že čerstvá DB má přesně 1 výchozí profil (Hráč 1).
func test_default_profile_created() -> void:
	if _skip_if_no_db():
		return
	ProfilesDao.ensure_default(_mem_db)
	var count: int = ProfilesDao.count(_mem_db)
	assert_eq(count, 1, "po ensure_default musí existovat právě 1 profil")


## Ověří jméno výchozího profilu.
func test_default_profile_name() -> void:
	if _skip_if_no_db():
		return
	ProfilesDao.ensure_default(_mem_db)
	var profiles: Array = ProfilesDao.get_all(_mem_db)
	assert_eq(profiles.size(), 1)
	assert_eq(str(profiles[0].get("name", "")), "Hráč 1", "výchozí profil musí mít jméno 'Hráč 1'")


## Ověří, že ensure_default nevloží druhý profil pokud jeden už existuje.
func test_default_profile_not_duplicated() -> void:
	if _skip_if_no_db():
		return
	ProfilesDao.ensure_default(_mem_db)
	ProfilesDao.ensure_default(_mem_db)
	assert_eq(ProfilesDao.count(_mem_db), 1, "ensure_default nesmí vytvořit duplicitní profil")


# ---------------------------------------------------------------------------
# ProfilesDao round-trip
# ---------------------------------------------------------------------------

func test_profiles_insert_and_fetch() -> void:
	if _skip_if_no_db():
		return
	var id: int = ProfilesDao.insert(_mem_db, "Testovací hráč", "avatar_01", 1700000000000)
	assert_true(id > 0, "insert musí vrátit platné id > 0")
	var row: Dictionary = ProfilesDao.get_by_id(_mem_db, id)
	assert_false(row.is_empty(), "get_by_id nesmí vrátit prázdný Dictionary")
	assert_eq(str(row.get("name", "")), "Testovací hráč")
	assert_eq(str(row.get("avatar_key", "")), "avatar_01")


func test_profiles_update() -> void:
	if _skip_if_no_db():
		return
	var id: int = ProfilesDao.insert(_mem_db, "Původní", "", 1700000000000)
	ProfilesDao.update(_mem_db, id, "Přejmenovaný", "avatar_02")
	var row: Dictionary = ProfilesDao.get_by_id(_mem_db, id)
	assert_eq(str(row.get("name", "")), "Přejmenovaný")
	assert_eq(str(row.get("avatar_key", "")), "avatar_02")


# ---------------------------------------------------------------------------
# SkillsDao round-trip
# ---------------------------------------------------------------------------

func test_skills_upsert_and_fetch() -> void:
	if _skip_if_no_db():
		return
	var pid: int = ProfilesDao.insert(_mem_db, "Hráč", "", 1700000000000)
	SkillsDao.upsert(_mem_db, pid, "add_0_20", 1050.5, 10, 8, 1700000001000)
	var row: Dictionary = SkillsDao.get_skill(_mem_db, pid, "add_0_20")
	assert_false(row.is_empty(), "get_skill nesmí vrátit prázdný Dictionary")
	assert_eq(float(row.get("rating", 0.0)), 1050.5)
	assert_eq(int(row.get("attempts", 0)), 10)
	assert_eq(int(row.get("correct", 0)), 8)


func test_skills_get_or_create() -> void:
	if _skip_if_no_db():
		return
	var pid: int = ProfilesDao.insert(_mem_db, "Hráč", "", 1700000000000)
	var row: Dictionary = SkillsDao.get_or_create(_mem_db, pid, "mul_x5")
	assert_false(row.is_empty())
	assert_eq(float(row.get("rating", 0.0)), 1000.0, "výchozí rating musí být 1000.0")


# ---------------------------------------------------------------------------
# SessionsDao round-trip
# ---------------------------------------------------------------------------

func test_sessions_insert_and_fetch() -> void:
	if _skip_if_no_db():
		return
	var pid: int = ProfilesDao.insert(_mem_db, "Hráč", "", 1700000000000)
	var sid: int = SessionsDao.insert(_mem_db, pid, 1700000000000, '{"duration_s":120}')
	assert_true(sid > 0, "session insert musí vrátit platné id")
	var row: Dictionary = SessionsDao.get_by_id(_mem_db, sid)
	assert_false(row.is_empty())
	assert_eq(int(row.get("profile_id", 0)), pid)


func test_sessions_close() -> void:
	if _skip_if_no_db():
		return
	var pid: int = ProfilesDao.insert(_mem_db, "Hráč", "", 1700000000000)
	var sid: int = SessionsDao.insert(_mem_db, pid, 1700000000000, "{}")
	SessionsDao.close_session(_mem_db, sid, 1700000120000, 120000, 350, 7, 0.875)
	var row: Dictionary = SessionsDao.get_by_id(_mem_db, sid)
	assert_eq(int(row.get("score", 0)), 350)
	assert_eq(int(row.get("best_streak", 0)), 7)
	assert_true(abs(float(row.get("accuracy", 0.0)) - 0.875) < 0.001)


# ---------------------------------------------------------------------------
# AttemptsDao round-trip
# ---------------------------------------------------------------------------

func test_attempts_insert_and_fetch() -> void:
	if _skip_if_no_db():
		return
	var pid: int = ProfilesDao.insert(_mem_db, "Hráč", "", 1700000000000)
	var sid: int = SessionsDao.insert(_mem_db, pid, 1700000000000, "{}")
	var aid: int = AttemptsDao.insert(
		_mem_db, sid, "add_0_20", "7 + 5", 12, [12, 13, 10], 0, true, 1500,
		1700000005000, 1700000006500
	)
	assert_true(aid > 0, "attempt insert musí vrátit platné id")
	var rows: Array = AttemptsDao.for_session(_mem_db, sid)
	assert_eq(rows.size(), 1)
	assert_eq(int(rows[0].get("correct", 0)), 1)
	assert_eq(int(rows[0].get("reaction_ms", 0)), 1500)


func test_attempts_miss() -> void:
	if _skip_if_no_db():
		return
	var pid: int = ProfilesDao.insert(_mem_db, "Hráč", "", 1700000000000)
	var sid: int = SessionsDao.insert(_mem_db, pid, 1700000000000, "{}")
	var aid: int = AttemptsDao.insert(
		_mem_db, sid, "add_0_20", "3 + 4", 7, [7, 8, 5], -1, false, -1,
		1700000005000, 1700000008000
	)
	assert_true(aid > 0)
	var rows: Array = AttemptsDao.for_session(_mem_db, sid)
	assert_eq(int(rows[0].get("correct", 1)), 0, "miss musí mít correct = 0")
	# chosen_index a reaction_ms musí být NULL
	assert_true(rows[0].get("chosen_index") == null, "miss: chosen_index musí být null")
	assert_true(rows[0].get("reaction_ms") == null, "miss: reaction_ms musí být null")


func test_attempts_count_by_skill() -> void:
	if _skip_if_no_db():
		return
	var pid: int = ProfilesDao.insert(_mem_db, "Hráč", "", 1700000000000)
	var sid: int = SessionsDao.insert(_mem_db, pid, 1700000000000, "{}")
	AttemptsDao.insert(_mem_db, sid, "add_0_20", "1+1", 2, [2, 3, 4], 0, true, 500, 1700000001000, 1700000001500)
	AttemptsDao.insert(_mem_db, sid, "add_0_20", "2+2", 4, [4, 5, 6], 0, true, 600, 1700000002000, 1700000002600)
	AttemptsDao.insert(_mem_db, sid, "sub_0_10", "5-3", 2, [2, 1, 3], 0, true, 700, 1700000003000, 1700000003700)
	var counts: Dictionary = AttemptsDao.count_by_skill(_mem_db, pid)
	assert_eq(int(counts.get("add_0_20", 0)), 2)
	assert_eq(int(counts.get("sub_0_10", 0)), 1)


# ---------------------------------------------------------------------------
# UnlocksDao round-trip
# ---------------------------------------------------------------------------

func test_unlocks_unlock_and_check() -> void:
	if _skip_if_no_db():
		return
	var pid: int = ProfilesDao.insert(_mem_db, "Hráč", "", 1700000000000)
	UnlocksDao.unlock(_mem_db, pid, "background", "space", 1700000010000)
	assert_true(UnlocksDao.is_unlocked(_mem_db, pid, "background", "space"))
	assert_false(UnlocksDao.is_unlocked(_mem_db, pid, "background", "forest"))


func test_unlocks_idempotent() -> void:
	if _skip_if_no_db():
		return
	var pid: int = ProfilesDao.insert(_mem_db, "Hráč", "", 1700000000000)
	UnlocksDao.unlock(_mem_db, pid, "badge", "first_correct", 1700000010000)
	UnlocksDao.unlock(_mem_db, pid, "badge", "first_correct", 1700000020000)
	var rows: Array = UnlocksDao.get_by_kind(_mem_db, pid, "badge")
	assert_eq(rows.size(), 1, "opakované odemknutí nesmí vytvořit duplicitní řádek")


# ---------------------------------------------------------------------------
# test_foreign_keys
# ---------------------------------------------------------------------------

## Ověří, že vložení attempt s neexistujícím session_id selže (FK constraint).
func test_foreign_keys_attempt_invalid_session() -> void:
	if _skip_if_no_db():
		return
	# Pokus o vložení attempt s neexistujícím session_id = 9999
	# godot-sqlite vrátí chybu; execute vrátí [] a neselže crash
	var before: Array = _mem_db.execute("SELECT COUNT(*) AS n FROM attempts;")
	var before_count: int = int(before[0].get("n", 0))

	# Toto by mělo selhat kvůli FK
	_mem_db.execute("""
		INSERT INTO attempts
			(session_id, skill_key, expression, correct_answer, choices_json,
			 correct, shown_at, resolved_at)
		VALUES (9999, 'add_0_20', '1+1', 2, '[2,3,4]', 1, 1700000000000, 1700000000500);
	""")

	var after: Array = _mem_db.execute("SELECT COUNT(*) AS n FROM attempts;")
	var after_count: int = int(after[0].get("n", 0))
	assert_eq(after_count, before_count, "FK violation: attempt s neplatným session_id nesmí být vložen")
