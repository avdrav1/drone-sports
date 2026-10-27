class_name ArcadeBezel
extends Control
# Act 1 framing: a crude in-game bezel, a fake leaderboard with the player's
# handle, and a one-line scout message on the first top-three finish.
# Shows only in jobs tagged with framing.tag. Text and a border only.

@export var framing: ArcadeFraming
@export var runner: JobRunner
@export var course: Course
## The player's racer.
@export var racer: Node3D
@export var border := 16.0

const FRAME := Color(0.07, 0.07, 0.09)
const EDGE := Color(1.0, 0.76, 0.25, 0.8)
const TEXT := Color(1, 1, 1, 0.85)
const DIM := Color(1, 1, 1, 0.45)
const ME := Color(1.0, 0.76, 0.25)

## True once this run fired the scout message.
var scout_shown := false
var font: Font

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	font = get_theme_default_font()
	visible = applies()
	if visible:
		runner.finished.connect(_on_finished)

func applies() -> bool:
	return framing != null and runner != null and runner.job != null and runner.job.tags.has(framing.tag)

func _process(_delta: float) -> void:
	queue_redraw()

func player_time() -> float:
	var p = course.progress(racer) if course and racer else null
	return p.finish_time if p and p.finished else INF

## Rows {handle, time, me}, fastest first; the player's unfinished run goes last.
func leaderboard() -> Array:
	var rows := []
	for h in framing.leaderboard:
		rows.append({"handle": h, "time": float(framing.leaderboard[h]), "me": false})
	rows.append({"handle": PlayerProfile.handle(), "time": player_time(), "me": true})
	rows.sort_custom(func(a, b): return a.time < b.time)
	return rows

func leaderboard_visible() -> bool:
	return runner.state == JobRunner.State.BRIEFING or player_time() < INF

func _on_finished(result: JobResult) -> void:
	var place := course.finish_order.find(racer) + 1
	if result.completed and place > 0 and place <= framing.scout_place and not StoryFlags.is_set(framing.scout_flag):
		StoryFlags.set_flag(framing.scout_flag)
		scout_shown = true

func _draw() -> void:
	var s := size
	var b := border
	# The bezel: a thick dark frame with a thin lit inner edge.
	draw_rect(Rect2(0, 0, s.x, b), FRAME)
	draw_rect(Rect2(0, s.y - b, s.x, b), FRAME)
	draw_rect(Rect2(0, 0, b, s.y), FRAME)
	draw_rect(Rect2(s.x - b, 0, b, s.y), FRAME)
	draw_rect(Rect2(b, b, s.x - b * 2.0, s.y - b * 2.0), EDGE, false, 1.0)
	draw_string(font, Vector2(b + 8, b - 3), framing.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
	draw_string(font, Vector2(s.x - b - 308, s.y - 4), framing.footer, HORIZONTAL_ALIGNMENT_RIGHT, 300, 11, DIM)
	draw_string(font, Vector2(b + 8, s.y - 4), "PLAYER  " + PlayerProfile.handle(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
	if leaderboard_visible():
		_draw_leaderboard(Vector2(s.x - b - 400, 150))
	if scout_shown:
		_draw_scout(s)

func _draw_leaderboard(at: Vector2) -> void:
	var rows := leaderboard()
	draw_rect(Rect2(at, Vector2(240, 34 + rows.size() * 22)), Color(0, 0, 0, 0.55))
	draw_string(font, at + Vector2(12, 22), "LEADERBOARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)
	var y := at.y + 46
	for i in rows.size():
		var r: Dictionary = rows[i]
		var col := ME if r.me else TEXT
		var t := "--" if r.time == INF else "%.1f" % r.time
		draw_string(font, Vector2(at.x + 12, y), "%d  %s" % [i + 1, r.handle], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		draw_string(font, Vector2(at.x + 150, y), t, HORIZONTAL_ALIGNMENT_RIGHT, 78, 14, col)
		y += 22

func _draw_scout(s: Vector2) -> void:
	var w := minf(760.0, s.x - 80.0)
	var rect := Rect2(Vector2((s.x - w) * 0.5, s.y - border - 96), Vector2(w, 64))
	draw_rect(rect, Color(0, 0, 0, 0.75))
	draw_rect(rect, EDGE, false, 1.0)
	draw_string(font, rect.position + Vector2(14, 22), "INCOMING MESSAGE  ·  " + framing.scout_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ME)
	draw_string(font, rect.position + Vector2(14, 46), framing.scout_line, HORIZONTAL_ALIGNMENT_LEFT, w - 28, 15, TEXT)
