class_name ParentGate
extends CanvasLayer
## Modal overlay that gates access to Settings / stats for grown-ups only.
## Asks a multiplication in the 11..19 range (trivial for adults, hard for children).
##
## Usage:
##   var gate := ParentGate.open(self)
##   gate.passed.connect(_on_pass)
##   gate.cancelled.connect(_on_cancel)

signal passed
signal cancelled

const SCENE_PATH: String = "res://scenes/shared/parent_gate.tscn"

var _correct_answer: int = 0

@onready var _question_label: Label = %QuestionLabel
@onready var _input: LineEdit = %AnswerInput
@onready var _feedback: Label = %FeedbackLabel
@onready var _confirm: Button = %ConfirmButton
@onready var _cancel: Button = %CancelButton
@onready var _panel: PanelContainer = %Panel


## Instantiates the gate, adds it as child of `parent`, and returns the instance.
static func open(parent: Node) -> ParentGate:
	var scene: PackedScene = load(SCENE_PATH)
	var gate: ParentGate = scene.instantiate()
	parent.add_child(gate)
	return gate


func _ready() -> void:
	get_viewport().size_changed.connect(_update_layout)
	_generate_question()
	_input.text_submitted.connect(_on_text_submitted)
	_confirm.pressed.connect(_on_confirm)
	_cancel.pressed.connect(_on_cancel)
	_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_input.grab_focus()
	_update_layout()


func _generate_question() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var a: int = rng.randi_range(11, 19)
	var b: int = rng.randi_range(11, 19)
	_correct_answer = a * b
	_question_label.text = "Kolik je %d × %d?" % [a, b]
	_feedback.text = ""
	_input.text = ""


func _update_layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var portrait := size.y > size.x
	if portrait:
		_panel.anchor_left = 0.08
		_panel.anchor_right = 0.92
		_panel.anchor_top = 0.08
		_panel.anchor_bottom = 0.08
		_panel.offset_left = 0.0
		_panel.offset_right = 0.0
		_panel.offset_top = 0.0
		_panel.offset_bottom = 420.0
	else:
		_panel.anchor_left = 0.5
		_panel.anchor_right = 0.5
		_panel.anchor_top = 0.08
		_panel.anchor_bottom = 0.08
		_panel.offset_left = -340.0
		_panel.offset_right = 340.0
		_panel.offset_top = 0.0
		_panel.offset_bottom = 380.0


func _on_text_submitted(_text: String) -> void:
	_on_confirm()


func _on_confirm() -> void:
	var given := _input.text.strip_edges()
	if not given.is_valid_int():
		_feedback.text = "Zadej číslo."
		return
	if int(given) == _correct_answer:
		passed.emit()
		queue_free()
	else:
		_feedback.text = "Špatně. Zkus to znovu."
		_generate_question()


func _on_cancel() -> void:
	cancelled.emit()
	queue_free()
