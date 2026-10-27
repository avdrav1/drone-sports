extends Control
# Results after a job: every objective and its score, crew strikes, the grade,
# pay, and reputation change. Retry reloads the job scene; Continue goes to continue_scene.

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
	money.text = "Pay %d     Reputation (%s) %+d" % [r.pay, r.job.faction, r.reputation_change]

## One line per struck character, e.g. "Marlo struck 1x".
static func strike_lines(r: JobResult) -> Array[String]:
	var out: Array[String] = []
	for id in r.strikes:
		var c: Character = Roster.character(id)
		out.append("%s struck %dx" % [c.name if c else String(id), r.strikes[id]])
	return out

func retry() -> void:
	retry_pressed.emit()
	if job_scene:
		get_tree().change_scene_to_file(job_scene)

func continue_on() -> void:
	continue_pressed.emit()
	get_tree().change_scene_to_file(continue_scene)
