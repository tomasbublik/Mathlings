class_name UnlocksDao
## DAO pro tabulku `unlocks`.
## Eviduje odemčené skiny, pozadí a odznaky pro každý profil.
## Všechny metody jsou statické.


## Odemkne položku pro profil. Pokud už existuje, nedělá nic (INSERT OR IGNORE).
static func unlock(
	db: Node,
	profile_id: int,
	kind: String,
	key: String,
	unlocked_at_ms: int = 0
) -> void:
	var ts: int = unlocked_at_ms if unlocked_at_ms > 0 else _now_ms()
	db.execute("""
		INSERT OR IGNORE INTO unlocks (profile_id, kind, key, unlocked_at)
		VALUES (?, ?, ?, ?);
	""", [profile_id, kind, key, ts])


## Vrátí true pokud profil danou položku už odemkl.
static func is_unlocked(db: Node, profile_id: int, kind: String, key: String) -> bool:
	var rows: Array = db.execute(
		"SELECT 1 FROM unlocks WHERE profile_id = ? AND kind = ? AND key = ?;",
		[profile_id, kind, key]
	)
	return not rows.is_empty()


## Vrátí všechny odemčené položky profilu jako Array[Dictionary].
static func get_for_profile(db: Node, profile_id: int) -> Array:
	return db.execute(
		"SELECT * FROM unlocks WHERE profile_id = ? ORDER BY unlocked_at;",
		[profile_id]
	)


## Vrátí odemčené položky daného druhu pro profil.
static func get_by_kind(db: Node, profile_id: int, kind: String) -> Array:
	return db.execute(
		"SELECT * FROM unlocks WHERE profile_id = ? AND kind = ? ORDER BY unlocked_at;",
		[profile_id, kind]
	)


## Pomocná funkce: unix milliseconds aktuálního času.
static func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
