class_name SkillsDao
## DAO pro tabulku `skills`.
## Uchovává Elo rating a statistiky pokusů pro každý (profile_id, skill_key) pár.
## Všechny metody jsou statické.


## Vloží nebo aktualizuje záznam dovednosti (UPSERT).
## Pokud záznam neexistuje, vytvoří jej s výchozími hodnotami.
static func upsert(
	db: Node,
	profile_id: int,
	skill_key: String,
	rating: float,
	attempts: int,
	correct: int,
	last_seen_at_ms: int
) -> void:
	db.execute("""
		INSERT INTO skills (profile_id, skill_key, rating, attempts, correct, last_seen_at)
		VALUES (?, ?, ?, ?, ?, ?)
		ON CONFLICT(profile_id, skill_key) DO UPDATE SET
			rating       = excluded.rating,
			attempts     = excluded.attempts,
			correct      = excluded.correct,
			last_seen_at = excluded.last_seen_at;
	""", [profile_id, skill_key, rating, attempts, correct, last_seen_at_ms])


## Vrátí záznam dovednosti nebo prázdný Dictionary, pokud neexistuje.
static func get_skill(db: Node, profile_id: int, skill_key: String) -> Dictionary:
	var rows: Array = db.execute(
		"SELECT * FROM skills WHERE profile_id = ? AND skill_key = ?;",
		[profile_id, skill_key]
	)
	if rows.is_empty():
		return {}
	return rows[0]


## Vrátí všechny dovednosti profilu jako Array[Dictionary].
static func get_for_profile(db: Node, profile_id: int) -> Array:
	return db.execute(
		"SELECT * FROM skills WHERE profile_id = ? ORDER BY skill_key;",
		[profile_id]
	)


## Vrátí nebo vytvoří dovednost s výchozím ratingem 1000.0.
static func get_or_create(db: Node, profile_id: int, skill_key: String) -> Dictionary:
	var row: Dictionary = get_skill(db, profile_id, skill_key)
	if row.is_empty():
		upsert(db, profile_id, skill_key, 1000.0, 0, 0, 0)
		row = get_skill(db, profile_id, skill_key)
	return row


## Aktualizuje rating a statistiky po jednom pokusu.
static func record_attempt(
	db: Node,
	profile_id: int,
	skill_key: String,
	new_rating: float,
	was_correct: bool,
	now_ms: int
) -> void:
	db.execute("""
		INSERT INTO skills (profile_id, skill_key, rating, attempts, correct, last_seen_at)
		VALUES (?, ?, ?, 1, ?, ?)
		ON CONFLICT(profile_id, skill_key) DO UPDATE SET
			rating       = excluded.rating,
			attempts     = attempts + 1,
			correct      = correct + excluded.correct,
			last_seen_at = excluded.last_seen_at;
	""", [profile_id, skill_key, new_rating, 1 if was_correct else 0, now_ms])
