extends Control
# Results after a job: every objective and its score, crew strikes, the grade,
# pay, reputation change, who was hurt or killed, and a closing line from the crew. Retry reloads the job scene; Continue goes to continue_scene.

signal retry_pressed
signal continue_pressed

@export_file("*.tscn") var continue_scene := "res://scenes/ui/job_board.tscn"
## The scene Retry reloads. Set by whoever shows the results.
var job_scene := ""
var result: JobResult
var offer_dialog: OfferDialog

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
	for e in r.epilogue:
		rows.add_child(epilogue_row(e))
	money.text = "Pay %d     Reputation (%s) %+d" % [r.pay, r.job.faction, r.reputation_change]
	if r.pay > 0:
		Sfx.play(&"job_payout")
	retry_button.disabled = not can_retry(r.job)
	retry_button.tooltip_text = "" if can_retry(r.job) else "This job is off the board now."
	show_offers()

## A death can take a job off the board (its faction locked, or crew it needs
## gone); Retry must not fly it anyway (Story 7.6).
static func can_retry(job: Job) -> bool:
	return job == null or (Consequences.listed(job) and Consequences.missing_crew(job).is_empty())

## Teams that now want the pilot ask here, one dialog at a time.
func show_offers() -> void:
	Career.check_offers()
	if offer_dialog == null:
		offer_dialog = OfferDialog.new()
		add_child(offer_dialog)
	offer_dialog.show_next()

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

## The last word from one crew member: theirs if alive, their memorial if not.
static func epilogue_row(e: Dictionary) -> HBoxContainer:
	var c: Character = Roster.character(e.id)
	var who := c.name if c else String(e.id)
	var text: String = ("%s: %s" % [who, e.text]) if e.alive else ("%s is not coming home. %s" % [who, e.text])
	return _face_row("Epilogue_%s" % e.id, c, text, not e.alive, Color.WHITE if e.alive else Color(1, 1, 1, 0.55))

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
	if result and not can_retry(result.job):
		return
	retry_pressed.emit()
	if job_scene:
		get_tree().change_scene_to_file(job_scene)

func continue_on() -> void:
	continue_pressed.emit()
	get_tree().change_scene_to_file(continue_scene)
