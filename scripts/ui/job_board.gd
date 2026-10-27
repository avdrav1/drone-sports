class_name JobBoard
extends Control
# The hub: wallet, reputation, and team in the header; every job with client,
# pay, and the assists it flies with; Fly on the ones the pilot's team takes,
# and who unlocks the rest; the crew and their status. Offers ask here too.

const JOBS := "res://data/jobs/board.tres"
const FREE_FLIGHT := "res://scenes/debug_flight.tscn"
const ACCENT := Color(1.0, 0.76, 0.25)
const DIM := Color(1, 1, 1, 0.55)
const HURT := Color(1.0, 0.45, 0.35)

var jobs: JobList
var offer_dialog: OfferDialog
## Job id -> its row, rebuilt on every refresh.
var job_rows := {}
## Character id -> its row.
var crew_rows := {}

var _header: Label
var _money: Label
var _jobs_box: VBoxContainer
var _crew_box: VBoxContainer
var _footer: HBoxContainer

func _ready() -> void:
	jobs = load(JOBS)
	set_anchors_preset(PRESET_FULL_RECT)
	_build()
	refresh()
	offer_dialog = OfferDialog.new()
	offer_dialog.answered.connect(func(_t, _a): refresh())
	add_child(offer_dialog)
	Career.check_offers()
	offer_dialog.show_next()

## Header text: wallet and reputation per faction.
func money_text() -> String:
	var reps: Array[String] = []
	for f in Team.FACTIONS:
		reps.append("%s %d" % [String(f).capitalize(), Reputation.of(f)])
	return "Wallet  %d        Reputation  %s" % [Wallet.balance, "   ".join(reps)]

## The act whose assists the job flies with: the job's or the career's, whichever has fewer.
static func preset_label(job: Job) -> String:
	var job_act := int(job.required_assists.label.trim_prefix("Act ")) if job.required_assists else 1
	return "Act %d" % maxi(job_act, Career.act())

## A job's row: [title, details, Fly button or lock text].
func refresh() -> void:
	_header.text = Career.label()
	_money.text = money_text()
	for c in _jobs_box.get_children():
		c.free()
	for c in _crew_box.get_children():
		c.free()
	job_rows.clear()
	crew_rows.clear()
	_jobs_box.add_child(_heading("JOBS"))
	for job in jobs.jobs:
		var row := _job_row(job)
		job_rows[job.id] = row
		_jobs_box.add_child(row)
	_crew_box.add_child(_heading("CREW"))
	for id in Roster.ids():
		var row := crew_row(id)
		crew_rows[id] = row
		_crew_box.add_child(row)

func fly_button(job_id: StringName) -> Button:
	var row: Node = job_rows.get(job_id)
	return row.get_node_or_null("Fly") if row else null

func fly(job: Job) -> void:
	if Career.can_fly(job) and job.scene:
		get_tree().change_scene_to_file(job.scene)

func free_flight() -> void:
	get_tree().change_scene_to_file(FREE_FLIGHT)

func _job_row(job: Job) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = String(job.id)
	row.add_theme_constant_override("separation", 16)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = job.title
	text.add_child(title)
	var details := Label.new()
	details.name = "Details"
	details.text = "%s  ·  %s  ·  pay %d  ·  %s assists" % [job.client, String(job.job_type).capitalize(), job.pay, preset_label(job)]
	details.add_theme_color_override("font_color", DIM)
	details.add_theme_font_size_override("font_size", 14)
	text.add_child(details)
	row.add_child(text)
	if Career.can_fly(job):
		var b := Button.new()
		b.name = "Fly"
		b.text = "Fly"
		b.custom_minimum_size.x = 90
		b.pressed.connect(fly.bind(job))
		row.add_child(b)
	else:
		var lock := Label.new()
		lock.name = "Locked"
		var teams := Career.unlocked_by(job)
		lock.text = "Locked: " + (", ".join(teams) if not teams.is_empty() else "no team yet")
		lock.add_theme_color_override("font_color", DIM)
		lock.add_theme_font_size_override("font_size", 14)
		lock.custom_minimum_size.x = 220
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(lock)
	return row

## Portrait, name and role, and status: active, injured for N jobs, or dead
## with a greyed portrait and their memorial line.
static func crew_row(id: StringName) -> HBoxContainer:
	var c: Character = Roster.character(id)
	var row := HBoxContainer.new()
	row.name = String(id)
	row.add_theme_constant_override("separation", 12)
	var face := CharacterPortrait.new()
	face.name = "Face"
	face.character = c
	face.greyed = not Roster.is_alive(id)
	face.custom_minimum_size = Vector2(44, 44)
	row.add_child(face)
	var text := Label.new()
	text.name = "Status"
	var status := "Active"
	var color := Color.WHITE
	match Roster.status(id):
		Roster.Status.INJURED:
			status = "Injured: out for %d more job%s" % [Roster.jobs_benched(id), "" if Roster.jobs_benched(id) == 1 else "s"]
			color = HURT
		Roster.Status.DEAD:
			var line := Bark.memorial(id)
			status = "Died." + ("  " + line if line else "")
			color = DIM
	text.text = "%s  ·  %s\n%s" % [c.name, c.role, status]
	text.add_theme_color_override("font_color", color)
	text.add_theme_font_size_override("font_size", 14)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 320
	text.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(text)
	return row

func _heading(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.35, 0.8, 0.95))
	l.add_theme_font_size_override("font_size", 13)
	return l

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	var head := HBoxContainer.new()
	page.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(titles)
	var title := Label.new()
	title.text = "JOB BOARD"
	title.add_theme_font_size_override("font_size", 28)
	titles.add_child(title)
	_header = Label.new()
	_header.add_theme_color_override("font_color", ACCENT)
	titles.add_child(_header)
	_money = Label.new()
	_money.size_flags_vertical = SIZE_SHRINK_END
	head.add_child(_money)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	page.add_child(body)
	_jobs_box = _panel(body, true)
	_crew_box = _panel(body, false)
	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.add_theme_constant_override("separation", 12)
	page.add_child(_footer)
	var free := Button.new()
	free.name = "FreeFlight"
	free.text = "Free flight"
	free.pressed.connect(free_flight)
	_footer.add_child(free)

func _panel(parent: Control, wide: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.6 if wide else 1.0
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	return box
