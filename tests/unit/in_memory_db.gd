class_name TestInMemoryDb
## Reusable test fixture: in-memory SQLite database that mimics the DB autoload.
## Mirrors the public surface every DAO uses (`execute`, `transaction`, `is_open`)
## so DAO/Service tests can run without touching disk.
##
## Usage in a GUT test:
##   var fix := TestInMemoryDb.new()
##   if not fix.open():
##       pending("godot-sqlite addon missing"); return
##   ...
##   fix.close()
##
## Skips silently when the godot-sqlite addon is not installed — every test that
## relies on this fixture should bail out via `pending()` in that case.

var _db: Object = null
var _is_open_flag: bool = false


## Opens an in-memory SQLite handle and applies migrations. Returns false when the
## godot-sqlite addon is not present (caller decides to skip / pending).
func open() -> bool:
	if not ClassDB.class_exists("SQLite"):
		return false
	_db = ClassDB.instantiate("SQLite")
	_db.path = ":memory:"
	_db.verbosity_level = 0  # SQLite.QUIET
	if not _db.open_db():
		return false
	_is_open_flag = true
	_db.query("PRAGMA foreign_keys = ON;")
	var migrations_script: GDScript = load("res://scripts/persistence/migrations.gd")
	migrations_script.run(_db)
	return true


func close() -> void:
	if _is_open_flag:
		_db.close_db()
		_db = null
		_is_open_flag = false


## Mirrors DB.is_open() so DbGuard.writable() works against the fixture.
func is_open() -> bool:
	return _is_open_flag


## Mirrors DB.execute(): returns Array[Dictionary] for SELECTs, [] otherwise.
func execute(sql: String, params: Array = []) -> Array:
	if not _is_open_flag:
		return []
	if params.is_empty():
		_db.query(sql)
	else:
		_db.query_with_bindings(sql, params)
	return (_db.get("query_result") as Array).duplicate(true)


## Mirrors DB.transaction(): runs `body`, commits on truthy result, rolls back otherwise.
func transaction(body: Callable) -> void:
	if not _is_open_flag:
		return
	_db.query("BEGIN;")
	var ok = body.call()
	if ok == null:
		ok = true
	if ok:
		_db.query("COMMIT;")
	else:
		_db.query("ROLLBACK;")
