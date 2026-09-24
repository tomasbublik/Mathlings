class_name AttemptsDao
## DAO pro tabulku `attempts`.
## Každý zobrazený příklad v herním kole = jeden attempt řádek.
## Všechny metody jsou statické.


## Vloží záznam o pokusu a vrátí přidělené id.
## chosen_index: -1 pokud příklad minul (hráč nestiskl tlačítko).
## reaction_ms:  -1 pokud příklad minul.
static func insert(
	db: Node,
	session_id: int,
	skill_key: String,
	expression: String,
	correct_answer: int,
	choices: Array,
	chosen_index: int,
	correct: bool,
	reaction_ms: int,
	shown_at_ms: int,
	resolved_at_ms: int
) -> int:
	var choices_json: String = JSON.stringify(choices)
	var ci = null if chosen_index < 0 else chosen_index
	var rm = null if reaction_ms < 0 else reaction_ms
	db.execute("""
		INSERT INTO attempts
			(session_id, skill_key, expression, correct_answer, choices_json,
			 chosen_index, correct, reaction_ms, shown_at, resolved_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
	""", [
		session_id, skill_key, expression, correct_answer, choices_json,
		ci, 1 if correct else 0, rm, shown_at_ms, resolved_at_ms
	])
	var rows: Array = db.execute("SELECT last_insert_rowid() AS id;")
	if rows.is_empty():
		return -1
	return int(rows[0].get("id", -1))


## Vrátí všechny pokusy dané session jako Array[Dictionary].
static func for_session(db: Node, session_id: int) -> Array:
	return db.execute(
		"SELECT * FROM attempts WHERE session_id = ? ORDER BY shown_at;",
		[session_id]
	)


## Vrátí Dictionary {skill_key: celkový_počet_pokusů} pro daný profil.
## Vyžaduje JOIN přes sessions.
static func count_by_skill(db: Node, profile_id: int) -> Dictionary:
	var rows: Array = db.execute("""
		SELECT a.skill_key, COUNT(*) AS n
		FROM attempts a
		JOIN sessions s ON s.id = a.session_id
		WHERE s.profile_id = ?
		GROUP BY a.skill_key;
	""", [profile_id])
	var result: Dictionary = {}
	for row in rows:
		result[str(row.get("skill_key", ""))] = int(row.get("n", 0))
	return result


## Vrátí počet správných pokusů dle skill_key pro daný profil.
static func correct_by_skill(db: Node, profile_id: int) -> Dictionary:
	var rows: Array = db.execute("""
		SELECT a.skill_key, SUM(a.correct) AS n
		FROM attempts a
		JOIN sessions s ON s.id = a.session_id
		WHERE s.profile_id = ?
		GROUP BY a.skill_key;
	""", [profile_id])
	var result: Dictionary = {}
	for row in rows:
		result[str(row.get("skill_key", ""))] = int(row.get("n", 0))
	return result
