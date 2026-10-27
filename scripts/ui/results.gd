extends Control
# Results after a job: every objective and its score, crew strikes, the grade,
# pay, reputation change, who was hurt or killed, and a closing line from the crew. Retry reloads the job scene; Continue goes to continue_scene.

signal retry_pressed
signal continue_pressed

@export_file("*.tscn") var continue_scene := "res://scenes/debug_flight.tscn"
## The scene Retry reloads. Set by whoever shows the results.
var job_scene := ""
var result: JobResult

@onready var title: Label = %Title
@onready var grade: Label = %Grade
@onready var rows: VBoxContainer = %Rows
@onready var money: Label = %Money
@onready var retry_button: Button = %Retry
@onready var continue_button: Button = %Continue

func _ready() -> void:
	retry_button.pressed.connect(retry)
	continue_button.pressed.connect(continue_on)
	continue_button.grab_focus()

func show_result(r: JobResult) -> void:
	result = r
	title.text = "%s  —  %s" % [r.job.title, "COMPLETE" if r.completed else "FAILED" + (" (%s)" % r.fail_reason if r.fail_reason else "")]
	grade.text = "Grade %s   (%d%%)" % [r.letter, roundi(r.score * 100.0)]
	for c in rows.get_children():
		c.queue_free()
	for o in r.objectives:
		var row := Label.new()
		row.text = "%-28s %3d%%   x%s" % [o.label, roundi(o.score * 100.0), str(o.weight)]
		rows.add_child(row)
	for line in strike_lines(r):
		var row := Label.new()
		row.text = line
		row.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		rows.add_child(row)
	for id in r.casualties:
		rows.add_child(casualty_row(r, id))
	if not r.bark.is_empty():
		rows.add_child(bark_row(r.bark))
	money.text = "Pay %d     Reputation (%s) %+d" % [r.pay, r.job.faction, r.reputation_change]

## One line per struck character, e.g. "Marlo struck 1x".
static func strike_lines(r: JobResult) -> Array[String]:
	var out: Array[String] = []
	for id in r.strikes:
		var c: Character = Roster.character(id)
		out.append("%s struck %dx" % [c.name if c else String(id), r.strikes[id]])
	return out

## A portrait beside "Name: line".
static func bark_row(b: Dictionary) -> HBoxContainer:
	var c: Character = Roster.character(b.id)
	return _face_row("Bark", c, "%s: %s" % [c.name if c else String(b.id), b.text], false, Color.WHITE)

## "Marlo injured, out for 2 jobs" with their line, or "Marlo died" with the
## memorial line and a greyed portrait.
static func casualty_row(r: JobResult, id: StringName) -> HBoxContainer:
	var c: Character = Roster.character(id)
	var who := c.name if c else String(id)
	var dead: bool = r.casualties[id] == Roster.Status.DEAD
	var head := "%s died." % who if dead else "%s injured, out for %d jobs." % [who, Roster.INJURY_JOBS]
	var line: String = r.casualty_lines.get(id, "")
	var text := head + ("\n" + ("" if dead else who + ": ") + line if line else "")
	return _face_row("Casualty", c, text, dead, Color(1.0, 0.45, 0.35))

static func _face_row(row_name: String, c: Character, text: String, greyed: bool, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	var face := CharacterPortrait.new()
	face.character = c
	face.greyed = greyed
	face.custom_minimum_size = Vector2(48, 48)
	row.add_child(face)
	var line := Label.new()
	line.text = text
	line.add_theme_color_override("font_color", color)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row

func retry() -> void:
	retry_pressed.emit()
	if job_scene:
		get_tree().change_scene_to_file(job_scene)

func continue_on() -> void:
	continue_pressed.emit()
	get_tree().change_scene_to_file(continue_scene)
