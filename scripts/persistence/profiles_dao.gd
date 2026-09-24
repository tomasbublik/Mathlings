class_name ProfilesDao
## DAO pro tabulku `profiles`.
## Všechny metody jsou statické; přijímají instanci DB autoloadu (nebo SQLite objekt).


## Vloží nový profil a vrátí přidělené id.
## created_at_ms: unix milliseconds; pokud je 0, použije se aktuální čas.
static func insert(db: Node, name: String, avatar_key: String = "", created_at_ms: int = 0) -> int:
	var ts: int = created_at_ms if created_at_ms > 0 else _now_ms()
	var rows: Array = db.execute(
		"INSERT INTO profiles (name, avatar_key, created_at) VALUES (?, ?, ?);",
		[name, avatar_key if avatar_key != "" else null, ts]
	)
	# Získá id posledního vloženého řádku
	var id_rows: Array = db.execute("SELECT last_insert_rowid() AS id;")
	if id_rows.is_empty():
		return -1
	return int(id_rows[0].get("id", -1))


## Vrátí všechny profily jako Array[Dictionary].
static func get_all(db: Node) -> Array:
	return db.execute("SELECT * FROM profiles ORDER BY id;")


## Vrátí profil dle id nebo prázdný Dictionary, pokud neexistuje.
static func get_by_id(db: Node, profile_id: int) -> Dictionary:
	var rows: Array = db.execute("SELECT * FROM profiles WHERE id = ?;", [profile_id])
	if rows.is_empty():
		return {}
	return rows[0]


## Aktualizuje jméno a avatar profilu. Vrátí true pokud byl řádek nalezen.
static func update(db: Node, profile_id: int, name: String, avatar_key: String = "") -> bool:
	db.execute(
		"UPDATE profiles SET name = ?, avatar_key = ? WHERE id = ?;",
		[name, avatar_key if avatar_key != "" else null, profile_id]
	)
	var rows: Array = db.execute("SELECT changes() AS n;")
	return int(rows[0].get("n", 0)) > 0


## Smaže profil dle id (cascade musí být řešen na úrovni FK).
static func delete(db: Node, profile_id: int) -> void:
	db.execute("DELETE FROM profiles WHERE id = ?;", [profile_id])


## Vrátí počet profilů v databázi.
static func count(db: Node) -> int:
	var rows: Array = db.execute("SELECT COUNT(*) AS n FROM profiles;")
	if rows.is_empty():
		return 0
	return int(rows[0].get("n", 0))


## Vloží výchozí profil id=1 pokud žádný profil neexistuje.
static func ensure_default(db: Node) -> void:
	if count(db) == 0:
		insert(db, "Hráč 1", "", _now_ms())


## Pomocná funkce: unix milliseconds aktuálního času.
static func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
