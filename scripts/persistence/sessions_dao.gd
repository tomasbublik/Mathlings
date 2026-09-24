class_name SessionsDao
## DAO pro tabulku `sessions`.
## Jedno kolo hry = jeden session řádek.
## Všechny metody jsou statické.


## Vloží nový session záznam (started_at) a vrátí přidělené id.
## config_json: JSON snapshot nastavení kola.
static func insert(db: Node, profile_id: int, started_at_ms: int, config_json: String) -> int:
	db.execute(
		"INSERT INTO sessions (profile_id, started_at, config_json) VALUES (?, ?, ?);",
		[profile_id, started_at_ms, config_json]
	)
	var rows: Array = db.execute("SELECT last_insert_rowid() AS id;")
	if rows.is_empty():
		return -1
	return int(rows[0].get("id", -1))


## Uzavře session po skončení kola — vyplní ended_at, duration_ms, score, best_streak, accuracy.
static func close_session(
	db: Node,
	session_id: int,
	ended_at_ms: int,
	duration_ms: int,
	score: int,
	best_streak: int,
	accuracy: float
) -> void:
	db.execute("""
		UPDATE sessions
		SET ended_at    = ?,
		    duration_ms = ?,
		    score       = ?,
		    best_streak = ?,
		    accuracy    = ?
		WHERE id = ?;
	""", [ended_at_ms, duration_ms, score, best_streak, accuracy, session_id])


## Smaže session řádek (přerušené kolo — "Quit round" v pauze).
## Pokusy session je nutné smazat předem (AttemptsDao.delete_for_session),
## jinak by je zablokoval cizí klíč attempts.session_id.
static func delete(db: Node, session_id: int) -> void:
	db.execute("DELETE FROM sessions WHERE id = ?;", [session_id])


## Vrátí session dle id nebo prázdný Dictionary.
static func get_by_id(db: Node, session_id: int) -> Dictionary:
	var rows: Array = db.execute("SELECT * FROM sessions WHERE id = ?;", [session_id])
	if rows.is_empty():
		return {}
	return rows[0]


## Vrátí seznam sessions pro daný profil seřazený sestupně dle started_at.
## limit 0 = bez limitu.
static func get_for_profile(db: Node, profile_id: int, limit: int = 0) -> Array:
	if limit > 0:
		return db.execute(
			"SELECT * FROM sessions WHERE profile_id = ? ORDER BY started_at DESC LIMIT ?;",
			[profile_id, limit]
		)
	return db.execute(
		"SELECT * FROM sessions WHERE profile_id = ? ORDER BY started_at DESC;",
		[profile_id]
	)


## Vrátí počet sessions profilu.
static func count_for_profile(db: Node, profile_id: int) -> int:
	var rows: Array = db.execute(
		"SELECT COUNT(*) AS n FROM sessions WHERE profile_id = ?;",
		[profile_id]
	)
	if rows.is_empty():
		return 0
	return int(rows[0].get("n", 0))


## Vrátí nejvyšší skóre dosažené v jakémkoli dokončeném kole daného profilu.
## Pokud profil ještě žádné dokončené kolo nemá, vrací 0.
static func max_score_for_profile(db: Node, profile_id: int) -> int:
	var rows: Array = db.execute("""
		SELECT COALESCE(MAX(score), 0) AS max_score
		FROM sessions
		WHERE profile_id = ? AND ended_at IS NOT NULL;
	""", [profile_id])
	if rows.is_empty():
		return 0
	return int(rows[0].get("max_score", 0))
