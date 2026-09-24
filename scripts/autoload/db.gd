extends Node
## Autoload DB — fasáda nad godot-sqlite.
## Otevře (nebo vytvoří) databázi v user://mathlings.db,
## aplikuje migrace a bootstrapuje výchozí profil.
##
## Použití:
##   DB.open()                            # voláno v _ready() nebo při startu aplikace
##   var rows := DB.execute("SELECT ...", [param1, param2])
##   DB.transaction(func(): DB.execute("INSERT ..."))
##   DB.close()
##
## Addon godot-sqlite (třída SQLite) musí být nainstalován v addons/godot-sqlite/.
## Pokud addon chybí, všechna volání bezpečně selžou s push_error() a vrátí [].

## Cesta k databázovému souboru v user:// adresáři.
const DB_PATH: String = "user://mathlings.db"

## Interní instance godot-sqlite (typ Object aby nevyžadoval SQLite při parsování).
var _db: Object = null

## True pokud je DB aktuálně otevřená.
var _is_open: bool = false


## Otevře (nebo vytvoří) databázi, zapne foreign keys a aplikuje migrace.
## Po prvním spuštění vloží výchozí profil přes ProfilesDao.
func open() -> void:
	if _is_open:
		return

	if not _sqlite_available():
		push_error("DB.open(): godot-sqlite addon není k dispozici. Viz addons/godot-sqlite/PLACEHOLDER.md.")
		return

	_db = ClassDB.instantiate("SQLite")
	_db.path = DB_PATH
	_db.verbosity_level = 0  # SQLite.QUIET == 0

	if not _db.open_db():
		push_error("DB.open(): nelze otevřít databázi na cestě: " + DB_PATH)
		_db = null
		return

	_is_open = true

	# Zapni foreign keys ihned po otevření (dle DESIGN §4 + P2 požadavek)
	_db.query("PRAGMA foreign_keys = ON;")

	# Aplikuj migrace (idempotentní)
	# Načítáme runtime aby se předešlo problémům s pořadím autoloadu
	var migrations_script: GDScript = load("res://scripts/persistence/migrations.gd")
	migrations_script.run(_db)

	# Bootstrap: vlož výchozí profil pokud neexistuje žádný
	var profiles_dao_script: GDScript = load("res://scripts/persistence/profiles_dao.gd")
	profiles_dao_script.ensure_default(self)


## Zavře databázi a uvolní prostředky.
func close() -> void:
	if not _is_open:
		return
	_db.close_db()
	_db = null
	_is_open = false


## Transakční helper.
## Spustí `body` uvnitř BEGIN/COMMIT transakce.
## Pokud body vrátí false nebo vyvolá chybu, transakce se rollbackuje.
func transaction(body: Callable) -> void:
	if not _is_open:
		push_error("DB.transaction(): databáze není otevřená.")
		return
	_db.query("BEGIN;")
	var ok = body.call()
	if ok == null:
		ok = true  # Callable nevrátila hodnotu — považujeme za úspěch
	if ok:
		_db.query("COMMIT;")
	else:
		_db.query("ROLLBACK;")


## Provede SQL dotaz s volitelně parametry (? zástupné symboly).
## Vrací Array[Dictionary] — každý Dictionary odpovídá jednomu řádku výsledku.
## Pokud DB není otevřená nebo addon chybí, vrátí [].
func execute(sql: String, params: Array = []) -> Array:
	if not _is_open:
		push_error("DB.execute(): databáze není otevřená. SQL: " + sql)
		return []

	# godot-sqlite API: query_with_bindings pro parametrizované dotazy
	if params.is_empty():
		_db.query(sql)
	else:
		_db.query_with_bindings(sql, params)

	# Vrátí kopii výsledku (query_result je sdílený Array — bezpečnější zkopírovat)
	return (_db.query_result as Array).duplicate(true)


## Vrací true pokud je třída SQLite k dispozici (addon nainstalován).
func _sqlite_available() -> bool:
	return ClassDB.class_exists("SQLite")


## Vrací true pokud je databáze aktuálně otevřená.
func is_open() -> bool:
	return _is_open
