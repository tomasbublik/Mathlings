## GUT unit tests for DbGuard.
## Two real callers are SkillModel/AttemptLogger (test paths inject null) and
## the live DB autoload. Tests cover both shapes plus an in-between fake.

extends GutTest


## Fake that quacks like the autoload but exposes is_open(); used to assert
## the helper actually consults the lifecycle method.
class FakeDb extends Node:
	var _open: bool = true

	func is_open() -> bool:
		return _open


## Fake without is_open() — DbGuard treats this as "ready" by contract
## (covers test fakes that omit the lifecycle method).
class BareDb extends Node:
	pass


func test_null_is_not_writable() -> void:
	assert_false(DbGuard.writable(null),
		"null reference must always be reported as not writable")


func test_open_db_is_writable() -> void:
	var fake := FakeDb.new()
	assert_true(DbGuard.writable(fake),
		"fake DB with is_open() == true must be writable")
	fake.free()


func test_closed_db_is_not_writable() -> void:
	var fake := FakeDb.new()
	fake._open = false
	assert_false(DbGuard.writable(fake),
		"fake DB with is_open() == false must be reported as not writable")
	fake.free()


func test_node_without_is_open_is_writable() -> void:
	# Plain Node lacks is_open() — DbGuard's contract is "treat as ready".
	var bare := BareDb.new()
	assert_true(DbGuard.writable(bare),
		"a Node without is_open() must be considered writable (test-fake contract)")
	bare.free()
