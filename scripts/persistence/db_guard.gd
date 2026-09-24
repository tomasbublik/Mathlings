class_name DbGuard
## Single-purpose helper that answers: "is this `db` reference safe to call now?".
##
## DAOs, the tutor, and the GameController all accept `db: Node` so unit tests can
## inject `null`. The runtime DB autoload also exposes `is_open()` to tell us
## whether `open()` has succeeded yet. Without a shared helper every caller would
## duplicate the same null-and-open guard — `db == null or (db.has_method("is_open")
## and not db.is_open())` — which drifts and obscures the actual logic.
##
## Use as `if not DbGuard.writable(db): return` at the top of any side-effecting
## method that accepts a `db: Node` parameter.


## True when `db` is non-null and (if it advertises `is_open()`) currently open.
## A `db` that lacks `is_open()` is treated as ready — covers test fakes that
## quack like the autoload without the lifecycle method.
static func writable(db: Node) -> bool:
	if db == null:
		return false
	if db.has_method("is_open"):
		return db.is_open()
	return true
