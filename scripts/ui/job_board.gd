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
# Story 17.5: one arcade menu (FLY, FREE FLIGHT, GARAGE, PILOT, CREW, OPTIONS)
# beside the pages. Up and down move through it, left and right flip the cards
# while FLY has focus, Enter selects, Esc goes back: from a page to the menu,
# from the menu to the title. CREW is its own page with big faces; OPTIONS
# holds Sound, Quality, and Watch intro.
# Story 17.6: it wears the FrontSkin for the act, the arcade cabinet in Act 1
# and the team's ops console from Act 2.
# It explains itself: a line on what the board is for, each card's job in one
# sentence, a hint for the focused menu item, and the controls along the bottom.
# Story 18.5: the crew notice you on their radio here: a hello as you come back
# (not right after someone died), a cheer for an upgrade bought or a job
# unlocked, and on Esc to the title a wave goodbye, said over the title screen.

const JOBS := "res://data/jobs/board.tres"
const FREE_FLIGHT := "res://scenes/debug_flight.tscn"
const INTRO := "res://scenes/story/intro.tscn"
const TITLE := "res://scenes/ui/title.tscn"
const DIM := Color(1, 1, 1, 0.55)
const HURT := Color(1.0, 0.45, 0.35)
## A fit crew member's perk on the CREW page (Story 19.7).
const GOOD := Color(0.55, 0.9, 0.55)
const HOW_TO := "Pick a job, fly it, get paid. Better grades pay more and get teams to notice you."
const CONTROLS := "UP/DOWN  MENU      LEFT/RIGHT  JOBS      ENTER  SELECT      ESC  BACK"
## What each menu item does, shown under the menu while it has focus.
const MENU_HINTS := {
	&"Fly": "Fly the job on the card.",
	&"FreeFlight": "Fly around the city. No job, no clock.",
	&"Garage": "Spend your pay on drone upgrades.",
	&"Pilot": "Choose who you fly as.",
	&"Crew": "See your crew and how they're doing.",
	&"Options": "Sound, graphics, and the intro.",
}

var jobs: JobList
## The look for this act; set before the board builds.
var skin: FrontSkin
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
## The menu's buttons, top to bottom.
var menu: VBoxContainer
## The page showing beside the menu: jobs, crew, or options.
var page := &"jobs"
var pages := {}
## The crew's lines on the board, and the radio that shows them (Story 18.5).
var bark: Bark
var radio: BarkBox
## Job ids flyable when the board last looked, this session; a new one is an unlock.
static var flyable_seen: Array[StringName] = []
static var flyable_known := false

var _header: Label
## The focused menu item's hint.
var menu_hint: Label
## Shows SaveGame.warning, once, when the save had to be reset.
var warning_label: Label
var _money: Label
var _crew_box: VBoxContainer
var _pilot_button: Button
var _shop_button: Button
var _crew_scroll: ScrollContainer

func _ready() -> void:
	jobs = load(JOBS)
	set_anchors_preset(PRESET_FULL_RECT)
	skin = FrontSkin.current()
	theme = skin.theme()
	_build_radio()
	_build()
	refresh()
	offer_dialog = OfferDialog.new()
	offer_dialog.answered.connect(func(_t, _a): refresh())
	add_child(offer_dialog)
	shop = ShopDialog.new()
	shop.purchased.connect(func():
		refresh()
		if not death_on_last_job():
			bark.moment(&"unlock"))
	add_child(shop)
	sound = SoundDialog.new()
	sound.name = "SoundDialog"
	add_child(sound)
	pilot_select = PilotSelect.new()
	pilot_select.name = "PilotSelect"
	pilot_select.visible = false
	pilot_select.chosen.connect(func(_id):
		refresh()
		menu_button(&"Fly").grab_focus())
	add_child(pilot_select)
	# Closed without a choice (Back), focus comes back to the menu.
	pilot_select.visibility_changed.connect(func():
		if not pilot_select.visible and get_viewport().gui_get_focus_owner() == null:
			menu_button(&"Fly").grab_focus())
	if not PlayerProfile.has_pilot():
		pilot_select.open()
	else:
		menu_button(&"Fly").grab_focus()
	if skin.scanlines:
		var lines := Scanlines.new()
		lines.name = "Scanlines"
		add_child(lines)
	UiSounds.wire(self)
	MusicDirector.title()
	Career.check_offers()
	offer_dialog.show_next()
	if PlayerProfile.has_pilot() and not death_on_last_job():
		bark.moment(&"hello")

## The radio sits on its own layer over the board, low on the left.
func _build_radio() -> void:
	bark = Bark.new()
	bark.name = "Bark"
	add_child(bark)
	var layer := CanvasLayer.new()
	layer.name = "Radio"
	add_child(layer)
	radio = BarkBox.new()
	radio.bark = bark
	layer.add_child(radio)
	radio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## True when someone died on the last job flown: the board stays quiet then.
static func death_on_last_job() -> bool:
	return Roster.ids().any(func(id): return Roster.status(id) == Roster.Status.DEAD and Roster.jobs_since_death(id) == 0)

## Says `unlock` when a job is flyable that was not the last time the board looked.
## After a death it only takes note: a lock a death sets can open jobs, and
## nobody cheers that.
func _note_unlocks() -> void:
	var now: Array[StringName] = []
	for job in jobs.jobs:
		if Consequences.listed(job) and Career.can_fly(job):
			now.append(job.id)
	var fresh: bool = flyable_known and now.any(func(id): return not id in flyable_seen)
	flyable_seen = now
	flyable_known = true
	if fresh and not death_on_last_job():
		bark.moment(&"unlock")

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
	_pilot_button.text = "PILOT  ·  %s" % PlayerProfile.pilot().name
	_money.text = money_text()
	var closed := Consequences.shop_closed_jobs()
	_shop_button.disabled = closed > 0
	# Disabled, it is skipped by keyboard and pad focus.
	_shop_button.focus_mode = FOCUS_NONE if closed > 0 else FOCUS_ALL
	_shop_button.text = "GARAGE" if closed == 0 else "GARAGE  closed %d more job%s" % [closed, "" if closed == 1 else "s"]
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
	for id in Roster.ids():
		var row := crew_row(id)
		crew_rows[id] = row
		_crew_box.add_child(row)
	_note_unlocks()

## The comms face on the card showing hops, as you pick that job.
func hop_comms() -> void:
	var card := carousel.current()
	var face: CharacterPortrait = card.find_child("Face", true, false) if card else null
	if face:
		face.hop()

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

## Esc (or pad B) with nothing open over the board: from a page back to the
## menu, from the menu back to the title.
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
	if page != &"jobs":
		back_to_menu()
	else:
		to_title()

func menu_button(n: StringName) -> Button:
	return menu.get_node_or_null(NodePath(n))

## Shows a page beside the menu: jobs, crew, or options.
func show_page(p: StringName) -> void:
	page = p
	for k in pages:
		pages[k].visible = k == p

## Shows the jobs again and puts focus back on the menu item that left them.
func back_to_menu() -> void:
	var from := {&"crew": &"Crew", &"options": &"Options"}.get(page, &"Fly") as StringName
	show_page(&"jobs")
	menu_button(from).grab_focus()

func open_crew() -> void:
	show_page(&"crew")
	pages[&"crew"].grab_focus()

func open_options() -> void:
	show_page(&"options")
	pages[&"options"].get_node("Box/Sound").grab_focus()

## FLY flies the card showing; from another page it shows the cards first.
func _on_fly_item() -> void:
	if page != &"jobs":
		show_page(&"jobs")
	else:
		fly_current()

## Left and right on FLY flip the cards instead of moving focus.
func _on_fly_item_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
		show_page(&"jobs")
		carousel.go(carousel.index + (1 if event.is_action_pressed("ui_right", true) else -1))
		menu_button(&"Fly").accept_event()

func to_title() -> void:
	# Nobody waves goodbye off a board that held its hello back for a death.
	TitleScreen.wave_goodbye = not death_on_last_job()
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
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	job_rows[job.id] = box
	job_ids.append(job.id)
	var info := VBoxContainer.new()
	info.name = "Info"
	info.add_theme_constant_override("separation", 6)
	box.add_child(info)
	var flies := BossGate.flyable() if boss else Career.can_fly(job)
	if not boss and job.id == start_here():
		var tag := Label.new()
		tag.name = "StartHere"
		tag.text = "START HERE"
		tag.add_theme_color_override("font_color", skin.accent)
		tag.theme_type_variation = &"Display"
		tag.add_theme_font_size_override("font_size", 16)
		info.add_child(tag)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	info.add_child(head)
	var icon := JobIcon.new()
	icon.name = "Icon"
	icon.kind = job.job_type
	icon.color = HURT if boss else skin.accent
	icon.custom_minimum_size = Vector2(44, 44)
	head.add_child(icon)
	var title := Label.new()
	title.text = job.title
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.theme_type_variation = &"Display"
	title.add_theme_font_size_override("font_size", 20)
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
	if job.summary != "":
		var summary := Label.new()
		summary.name = "Summary"
		summary.text = job.summary
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_theme_font_size_override("font_size", 20)
		info.add_child(summary)
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
	details.add_theme_font_size_override("font_size", 18)
	info.add_child(details)
	var grade := Label.new()
	grade.name = "Grade"
	var best := Career.best_grade(job.id)
	grade.text = "BEST GRADE  " + (best if best != "" else "-")
	grade.add_theme_color_override("font_color", skin.heading)
	grade.theme_type_variation = &"Display"
	grade.add_theme_font_size_override("font_size", 16)
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
		b.add_theme_font_size_override("font_size", 22)
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
		lock.add_theme_font_size_override("font_size", 19)
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
	face.custom_minimum_size = Vector2(64, 64)
	face.follow_mouse = true
	row.add_child(face)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	var who_label := Label.new()
	who_label.text = "%s  ·  %s  ·  ON COMMS" % [c.name, c.role]
	who_label.add_theme_color_override("font_color", skin.accent)
	who_label.add_theme_font_size_override("font_size", 17)
	text.add_child(who_label)
	var pitch := Label.new()
	pitch.name = "Pitch"
	pitch.text = "\"%s\"" % line.get("text", "")
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.add_theme_font_size_override("font_size", 19)
	text.add_child(pitch)
	return row

## Portrait, name and role, and status: active, injured for N jobs, or dead
## with a greyed portrait and their memorial line. Under it, a support crew
## member's perk (Story 19.7): on, struck through while benched, lost once dead.
static func crew_row(id: StringName) -> HBoxContainer:
	var c: Character = Roster.character(id)
	var row := HBoxContainer.new()
	row.name = String(id)
	row.add_theme_constant_override("separation", 12)
	var face := CharacterPortrait.new()
	face.name = "Face"
	face.character = c
	face.greyed = not Roster.is_alive(id)
	face.custom_minimum_size = Vector2(88, 88)
	face.follow_mouse = true
	# Clicking someone on the crew page makes them hop.
	face.mouse_filter = MOUSE_FILTER_PASS
	face.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			face.hop())
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
	text.add_theme_font_size_override("font_size", 18)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 240
	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.size_flags_vertical = SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	info.add_child(text)
	if c.perk:
		info.add_child(perk_label(id))
	row.add_child(info)
	return row

## The perk line under a crew row: what they bring while fit, struck through
## with the jobs left while benched, a memorial note once dead.
static func perk_label(id: StringName) -> RichTextLabel:
	var p: CrewPerk = Roster.character(id).perk
	var l := RichTextLabel.new()
	l.name = "Perk"
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("normal_font_size", 16)
	var line := p.line().replace("[", "[lb]")
	match Roster.status(id):
		Roster.Status.ACTIVE:
			l.text = "[color=#%s]%s[/color]" % [GOOD.to_html(false), line]
		Roster.Status.INJURED:
			var left := Roster.jobs_benched(id)
			l.text = "[color=#%s]Off for %d more job%s:  [s]%s[/s][/color]" % [HURT.to_html(false), left, "" if left == 1 else "s", line]
		Roster.Status.DEAD:
			l.text = "[color=#%s]No more %s[/color]" % [DIM.to_html(true), p.name]
	return l

func _heading(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", skin.heading)
	l.theme_type_variation = &"Display"
	l.add_theme_font_size_override("font_size", 16)
	return l

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = skin.background
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var head := HBoxContainer.new()
	page.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(titles)
	var title := Label.new()
	title.text = "JOB BOARD"
	title.theme_type_variation = &"Display"
	title.add_theme_font_size_override("font_size", 36)
	titles.add_child(title)
	_header = Label.new()
	_header.add_theme_color_override("font_color", skin.accent)
	_header.add_theme_font_size_override("font_size", 22)
	titles.add_child(_header)
	_money = Label.new()
	_money.size_flags_vertical = SIZE_SHRINK_END
	_money.add_theme_font_size_override("font_size", 20)
	head.add_child(_money)
	var how := Label.new()
	how.name = "HowTo"
	how.text = HOW_TO
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.add_theme_font_size_override("font_size", 20)
	page.add_child(how)
	warning_label = Label.new()
	warning_label.add_theme_color_override("font_color", HURT)
	warning_label.text = SaveGame.warning
	warning_label.visible = SaveGame.warning != ""
	SaveGame.warning = ""
	page.add_child(warning_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	page.add_child(body)
	_build_menu(body)
	var stack := Control.new()
	stack.name = "Pages"
	stack.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(stack)
	carousel = JobCarousel.new()
	carousel.name = "Carousel"
	carousel.set_anchors_preset(PRESET_FULL_RECT)
	carousel.accent = skin.accent
	carousel.activated.connect(func(_i): fly_current())
	carousel.moved.connect(func(_i): hop_comms())
	stack.add_child(carousel)
	pages[&"jobs"] = carousel
	_crew_box = _panel(stack, &"crew")
	_crew_scroll = _crew_box.get_parent() as ScrollContainer
	# The page itself takes focus (a ScrollContainer only does while it can
	# scroll); up and down scroll it, and its border lights while focused.
	var crew_page: PanelContainer = pages[&"crew"]
	crew_page.focus_mode = FOCUS_ALL
	crew_page.gui_input.connect(_on_crew_scroll_input)
	crew_page.focus_entered.connect(func():
		var lit: StyleBoxFlat = crew_page.get_theme_stylebox("panel").duplicate()
		lit.border_color = skin.accent
		crew_page.add_theme_stylebox_override("panel", lit))
	crew_page.focus_exited.connect(func(): crew_page.remove_theme_stylebox_override("panel"))
	_crew_box.add_theme_constant_override("separation", 16)
	_build_options(stack)
	var controls := Label.new()
	controls.name = "Controls"
	controls.text = CONTROLS
	controls.theme_type_variation = &"Display"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_color_override("font_color", DIM)
	controls.add_theme_font_size_override("font_size", 12)
	page.add_child(controls)
	# Keyboard and pad focus leaving the cards goes back to FLY.
	var fly_path := carousel.get_path_to(menu_button(&"Fly"))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_BOTTOM]:
		carousel.set_focus_neighbor(side, fly_path)
	show_page(&"jobs")

func _build_menu(parent: Control) -> void:
	menu = VBoxContainer.new()
	menu.name = "Menu"
	menu.custom_minimum_size.x = 270
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 10)
	parent.add_child(menu)
	var items := [["Fly", "FLY", _on_fly_item], ["FreeFlight", "FREE FLIGHT", free_flight],
		["Garage", "GARAGE", func(): shop.open()], ["Pilot", "PILOT", func(): pilot_select.open()],
		["Crew", "CREW", open_crew], ["Options", "OPTIONS", open_options]]
	for it in items:
		var b := Button.new()
		b.name = it[0]
		b.text = it[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(it[2])
		b.focus_entered.connect(func(): menu_hint.text = MENU_HINTS[b.name])
		b.mouse_entered.connect(func(): menu_hint.text = MENU_HINTS[b.name])
		menu.add_child(b)
	menu_hint = Label.new()
	menu_hint.name = "Hint"
	menu_hint.text = MENU_HINTS[&"Fly"]
	menu_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_hint.custom_minimum_size.y = 56
	menu_hint.add_theme_color_override("font_color", DIM)
	menu_hint.add_theme_font_size_override("font_size", 18)
	menu.add_child(menu_hint)
	_shop_button = menu_button(&"Garage")
	_pilot_button = menu_button(&"Pilot")
	menu_button(&"Fly").gui_input.connect(_on_fly_item_input)
	menu_button(&"Fly").focus_entered.connect(func(): carousel.highlight = true)
	menu_button(&"Fly").focus_exited.connect(func(): carousel.highlight = false)
	# The menu wraps top to bottom, and left and right never wander off it.
	var buttons := menu.get_children().filter(func(c): return c is Button)
	for i in buttons.size():
		var b: Button = buttons[i]
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
	buttons[0].focus_neighbor_top = buttons[0].get_path_to(buttons[-1])
	buttons[-1].focus_neighbor_bottom = buttons[-1].get_path_to(buttons[0])

func _build_options(stack: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "Options"
	panel.set_anchors_preset(PRESET_FULL_RECT)
	stack.add_child(panel)
	pages[&"options"] = panel
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(_heading("OPTIONS"))
	var sound_button := Button.new()
	sound_button.name = "Sound"
	sound_button.text = "Sound"
	sound_button.pressed.connect(func(): sound.open())
	box.add_child(sound_button)
	# Renderer extras (Story 15.1); the web build is always Low, so no choice there.
	var quality := OptionButton.new()
	quality.name = "Quality"
	quality.add_item("Quality: Low", Quality.Tier.LOW)
	quality.add_item("Quality: High", Quality.Tier.HIGH)
	quality.select(quality.get_item_index(GameSettings.quality))
	quality.item_selected.connect(func(i): set_quality(quality.get_item_id(i)))
	quality.visible = not OS.has_feature("web")
	box.add_child(quality)
	var intro := Button.new()
	intro.name = "WatchIntro"
	intro.text = "Watch intro"
	intro.pressed.connect(watch_intro)
	box.add_child(intro)
	for c in [sound_button, quality, intro]:
		c.size_flags_horizontal = SIZE_SHRINK_BEGIN
		c.custom_minimum_size.x = 280
		# Left goes back to the menu item that opened the page.
		c.focus_neighbor_left = c.get_path_to(menu_button(&"Options"))
	var esc := Label.new()
	esc.text = "Esc to go back"
	esc.add_theme_color_override("font_color", DIM)
	esc.add_theme_font_size_override("font_size", 14)
	box.add_child(esc)

## Up and down scroll the crew page.
func _on_crew_scroll_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed("ui_down", true):
		step = 1
	elif event.is_action_pressed("ui_up", true):
		step = -1
	if step != 0:
		_crew_scroll.scroll_vertical += step * 120
		pages[&"crew"].accept_event()

## A page holding a scrolling list, e.g. the crew.
func _panel(stack: Control, key: StringName) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = String(key).capitalize()
	panel.set_anchors_preset(PRESET_FULL_RECT)
	stack.add_child(panel)
	pages[key] = panel
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)
	outer.add_child(_heading(String(key).to_upper()))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	return box
