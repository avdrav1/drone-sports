class_name JobBoard
extends Control
# The hub: wallet, reputation, and team in the header; every job with client,
# pay, and the assists it flies with; Fly on the ones the pilot's team takes,
# and who unlocks the rest; the crew and their status. Offers ask here too,
# and the shop and pilot select open from here. A new game picks a pilot first.
# A locked faction's jobs leave the board, and the shop shows when it is closed
# (Story 7.6). Esc goes back to the title (Story 17.3).
# Story 17.4: the jobs are a carousel of big cards, one at a time: title, client,
# type icon, pay, assists, best grade, and a crew member on comms pitching it in
# their own voice. A locked card shows a padlock and one short reason, the full
# one in its tooltip. It opens on START HERE, else on the last job flown.

const JOBS := "res://data/jobs/board.tres"
const FREE_FLIGHT := "res://scenes/debug_flight.tscn"
const INTRO := "res://scenes/story/intro.tscn"
const TITLE := "res://scenes/ui/title.tscn"
const ACCENT := Color(1.0, 0.76, 0.25)
const DIM := Color(1, 1, 1, 0.55)
const HURT := Color(1.0, 0.45, 0.35)

var jobs: JobList
var offer_dialog: OfferDialog
var shop: ShopDialog
var pilot_select: PilotSelect
var sound: SoundDialog
## Job id -> its card's content (Fly or Locked inside), rebuilt on every refresh.
var job_rows := {}
## Job ids in carousel order.
var job_ids: Array[StringName] = []
var carousel: JobCarousel
## Character id -> its row.
var crew_rows := {}

var _header: Label
## Shows SaveGame.warning, once, when the save had to be reset.
var warning_label: Label
var _money: Label
var _crew_box: VBoxContainer
var _footer: HBoxContainer
var _pilot_button: Button
var _shop_button: Button

func _ready() -> void:
	jobs = load(JOBS)
	set_anchors_preset(PRESET_FULL_RECT)
	_build()
	refresh()
	offer_dialog = OfferDialog.new()
	offer_dialog.answered.connect(func(_t, _a): refresh())
	add_child(offer_dialog)
	shop = ShopDialog.new()
	shop.purchased.connect(refresh)
	add_child(shop)
	sound = SoundDialog.new()
	sound.name = "SoundDialog"
	add_child(sound)
	pilot_select = PilotSelect.new()
	pilot_select.name = "PilotSelect"
	pilot_select.visible = false
	pilot_select.chosen.connect(func(_id):
		refresh()
		carousel.grab_focus())
	add_child(pilot_select)
	if not PlayerProfile.has_pilot():
		pilot_select.open()
	else:
		carousel.grab_focus()
	UiSounds.wire(self)
	MusicDirector.board()
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
	_pilot_button.text = "Pilot: %s" % PlayerProfile.pilot().name
	_money.text = money_text()
	var closed := Consequences.shop_closed_jobs()
	_shop_button.disabled = closed > 0
	_shop_button.text = "Shop" if closed == 0 else "Shop closed: %d more job%s" % [closed, "" if closed == 1 else "s"]
	_shop_button.tooltip_text = "" if closed == 0 else "Closed since %s died." % \
		", ".join(Consequences.causes(&"shop_closed").map(func(c): return c.name))
	for c in _crew_box.get_children():
		c.free()
	var showing: StringName = job_ids[carousel.index] if carousel.index < job_ids.size() else &""
	job_rows.clear()
	job_ids.clear()
	crew_rows.clear()
	var cards: Array[Control] = []
	for job in jobs.jobs:
		if not Consequences.listed(job):
			continue
		cards.append(_card(job, false))
	# The Lattice is data-gated: switched off, it is never listed (Story 8.1).
	if BossGate.listed():
		cards.append(_card(BossGate.data().job, true))
	var open_on := job_ids.find(showing if showing != &"" else opening_job())
	carousel.set_cards(cards, maxi(open_on, 0))
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

## Picks the renderer tier (Quality.Tier) and saves it; scenes loaded after use it.
func set_quality(tier: int) -> void:
	GameSettings.quality = tier
	GameSettings.save()

## Esc (or pad B) with nothing open over the board: back to the title.
## Left and right flip the carousel even when nothing has focus.
func _unhandled_input(event: InputEvent) -> void:
	if pilot_select.visible:
		return
	if get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		carousel.grab_focus()
		carousel.go(carousel.index + (1 if event.is_action_pressed("ui_right") else -1))
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	for w in find_children("*", "Window", true, false):
		if w.visible:
			return
	get_viewport().set_input_as_handled()
	to_title()

func to_title() -> void:
	get_tree().change_scene_to_file(TITLE)

func free_flight() -> void:
	get_tree().change_scene_to_file(FREE_FLIGHT)

func watch_intro() -> void:
	CutscenePlayer.replay = true
	get_tree().change_scene_to_file(INTRO)

## The card the carousel opens on: START HERE, else the last job flown.
func opening_job() -> StringName:
	var start := start_here()
	return start if start != &"" else Career.last_job

## Enter or a click on the shown card: fly it, or shake when it is locked.
func fly_current() -> void:
	var b := fly_button(job_ids[carousel.index]) if carousel.index < job_ids.size() else null
	if b:
		b.pressed.emit()
	else:
		carousel.shake()

## Who pitches a job: the first living crew member in its field, then those it
## needs alive, then whoever speaks at briefings, with a pitch line to say.
static func comms_for(job: Job) -> StringName:
	var who: Array[StringName] = []
	who.append_array(job.crew_in_field)
	who.append_array(job.requires_living)
	for id in Roster.ids():
		var c: Character = Roster.character(id)
		if c and &"briefing" in c.speaks_on:
			who.append(id)
	for id in who:
		if Roster.is_alive(id) and not Bark.pool(id, &"pitch").is_empty():
			return id
	return &""

## Why a job is locked, short for the card and in full for its tooltip.
static func lock_reason(job: Job) -> Array[String]:
	var missing := Consequences.missing_crew(job)
	if not missing.is_empty():
		return ["Needs " + " and ".join(missing), "Closed: needs %s alive to fly it." % ", ".join(missing)]
	var teams := Career.unlocked_by(job)
	if teams.is_empty():
		return ["No team flies this", "Locked: no team takes this kind of job yet."]
	var short := "Join " + teams[0]
	if teams.size() == 2:
		short += " or " + teams[1]
	elif teams.size() > 2:
		short += " or %d more teams" % (teams.size() - 1)
	return [short, "Locked: flown by %s. Join one to fly it." % ", ".join(teams)]

## Before anything is done, the first flyable job is where to start.
func start_here() -> StringName:
	if Career.team_id != &"" or not Career.completed.is_empty():
		return &""
	for job in jobs.jobs:
		if Career.can_fly(job):
			return job.id
	return &""

## A job's card: a panel holding a box named for the job, whose first child is
## the info (StartHere, Details, Grade, Comms) and whose last is Fly or Locked.
func _card(job: Job, boss: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Card_" + String(job.id)
	panel.mouse_filter = MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.name = String(job.id)
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	job_rows[job.id] = box
	job_ids.append(job.id)
	var info := VBoxContainer.new()
	info.name = "Info"
	info.add_theme_constant_override("separation", 8)
	box.add_child(info)
	var flies := BossGate.flyable() if boss else Career.can_fly(job)
	if not boss and job.id == start_here():
		var tag := Label.new()
		tag.name = "StartHere"
		tag.text = "START HERE"
		tag.add_theme_color_override("font_color", ACCENT)
		tag.add_theme_font_size_override("font_size", 15)
		info.add_child(tag)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	info.add_child(head)
	var icon := JobIcon.new()
	icon.name = "Icon"
	icon.kind = job.job_type
	icon.color = HURT if boss else ACCENT
	icon.custom_minimum_size = Vector2(52, 52)
	head.add_child(icon)
	var title := Label.new()
	title.text = job.title
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 30)
	if boss:
		title.add_theme_color_override("font_color", HURT)
	head.add_child(title)
	if not flies:
		var padlock := JobIcon.new()
		padlock.name = "Padlock"
		padlock.kind = &"locked"
		padlock.color = DIM
		padlock.custom_minimum_size = Vector2(36, 36)
		head.add_child(padlock)
	var details := Label.new()
	details.name = "Details"
	if boss:
		details.text = "%s  ·  Lethal for crew in the field  ·  pay %d  ·  %s assists" % [job.client, job.pay, preset_label(job)]
	else:
		details.text = "%s  ·  %s  ·  pay %d  ·  %s assists" % [job.client, String(job.job_type).capitalize(), job.pay, preset_label(job)]
		var done := Career.times_completed(job.id)
		if done > 0:
			details.text += "  ·  done %d×" % done
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", DIM)
	details.add_theme_font_size_override("font_size", 16)
	info.add_child(details)
	var grade := Label.new()
	grade.name = "Grade"
	var best := Career.best_grade(job.id)
	grade.text = "BEST GRADE  " + (best if best != "" else "-")
	grade.add_theme_color_override("font_color", Color(0.35, 0.8, 0.95))
	grade.add_theme_font_size_override("font_size", 18)
	info.add_child(grade)
	# The Lattice gets no cheerful pitch; its row keeps its own say (Story 8.1).
	var who := comms_for(job) if not boss else &""
	if who != &"":
		info.add_child(_comms(job, who))
	if flies:
		var b := Button.new()
		b.name = "Fly"
		b.text = "FLY"
		b.focus_mode = FOCUS_NONE
		b.size_flags_horizontal = SIZE_SHRINK_CENTER
		b.custom_minimum_size = Vector2(220, 0)
		b.add_theme_font_size_override("font_size", 24)
		if boss:
			b.pressed.connect(func(): BossGate.open(get_tree()))
		else:
			b.pressed.connect(fly.bind(job))
		box.add_child(b)
	else:
		var lock := Label.new()
		lock.name = "Locked"
		lock.mouse_filter = MOUSE_FILTER_PASS
		if boss:
			lock.text = "Unreachable: " + "; ".join(BossGate.reasons())
			lock.tooltip_text = lock.text
		else:
			var why := lock_reason(job)
			lock.text = why[0]
			lock.tooltip_text = why[1]
		panel.tooltip_text = lock.tooltip_text
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.add_theme_color_override("font_color", DIM)
		lock.add_theme_font_size_override("font_size", 20)
		box.add_child(lock)
	return panel

## The crew member on comms for a job: their face making the pitch's
## expression, name and role, and the line.
func _comms(job: Job, who: StringName) -> HBoxContainer:
	var c: Character = Roster.character(who)
	var line := Bark.pitch(who, job.id)
	var row := HBoxContainer.new()
	row.name = "Comms"
	row.add_theme_constant_override("separation", 14)
	var face := CharacterPortrait.new()
	face.name = "Face"
	face.character = c
	face.expression = line.get("face", &"neutral")
	face.custom_minimum_size = Vector2(76, 76)
	row.add_child(face)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	var who_label := Label.new()
	who_label.text = "%s  ·  %s  ·  ON COMMS" % [c.name, c.role]
	who_label.add_theme_color_override("font_color", ACCENT)
	who_label.add_theme_font_size_override("font_size", 14)
	text.add_child(who_label)
	var pitch := Label.new()
	pitch.name = "Pitch"
	pitch.text = "\"%s\"" % line.get("text", "")
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(pitch)
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
	warning_label = Label.new()
	warning_label.add_theme_color_override("font_color", HURT)
	warning_label.text = SaveGame.warning
	warning_label.visible = SaveGame.warning != ""
	SaveGame.warning = ""
	page.add_child(warning_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	page.add_child(body)
	carousel = JobCarousel.new()
	carousel.name = "Carousel"
	carousel.size_flags_horizontal = SIZE_EXPAND_FILL
	carousel.size_flags_stretch_ratio = 1.6
	carousel.activated.connect(func(_i): fly_current())
	body.add_child(carousel)
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
	_shop_button = Button.new()
	_shop_button.name = "Shop"
	_shop_button.text = "Shop"
	_shop_button.pressed.connect(func(): shop.open())
	_footer.add_child(_shop_button)
	_pilot_button = Button.new()
	_pilot_button.name = "Pilot"
	_pilot_button.pressed.connect(func(): pilot_select.open())
	_footer.add_child(_pilot_button)
	var sound_button := Button.new()
	sound_button.name = "Sound"
	sound_button.text = "Sound"
	sound_button.pressed.connect(func(): sound.open())
	_footer.add_child(sound_button)
	# Renderer extras (Story 15.1); the web build is always Low, so no choice there.
	var quality := OptionButton.new()
	quality.name = "Quality"
	quality.add_item("Quality: Low", Quality.Tier.LOW)
	quality.add_item("Quality: High", Quality.Tier.HIGH)
	quality.select(quality.get_item_index(GameSettings.quality))
	quality.item_selected.connect(func(i): set_quality(quality.get_item_id(i)))
	quality.visible = not OS.has_feature("web")
	_footer.add_child(quality)
	var intro := Button.new()
	intro.name = "WatchIntro"
	intro.text = "Watch intro"
	intro.pressed.connect(watch_intro)
	_footer.add_child(intro)

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
