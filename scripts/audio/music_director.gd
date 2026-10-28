extends Node
# Autoload "MusicDirector" (Story 16.4): chooses what Music plays. The score is
# the act's (data/music/act_<n>.tres from Career.act(), or the nearest earlier
# act that has one), and which of its stems sound follows where the player is:
# the board and briefing play the drone and pad, the countdown adds the
# arpeggio, flying brings in every stem, and the results screen drops back to
# the drone and pad. Stems a state does not name fade to Music.SILENT_DB; the
# rest go to their Stem.level_db. JobRunner hands itself to watch(), the board
# calls board(), and a cutscene with a score plays it through play_score().
# Runners that do not pay out (cutscene backdrops, previews) are ignored.

const SCORE_PATH := "res://data/music/act_%d.tres"
## Stems that sound in each mix; ALL means every stem in the score.
const ALL := [&"*"]
const MIXES := {
	&"board": [&"drone", &"pad"],
	&"briefing": [&"drone", &"pad"],
	&"countdown": [&"drone", &"pad", &"arp"],
	&"live": ALL,
	&"results": [&"drone", &"pad"],
}
## The mix for each runner state.
const STATE_MIX := {
	JobRunner.State.IDLE: &"board",
	JobRunner.State.BRIEFING: &"briefing",
	JobRunner.State.COUNTDOWN: &"countdown",
	JobRunner.State.LIVE: &"live",
	JobRunner.State.COMPLETE: &"results",
	JobRunner.State.FAILED: &"results",
}

## The mix last set.
var mix: StringName = &""

## The score for `act`: its own, or the nearest earlier act's. Null if none.
func score_for(act: int) -> Score:
	for n in range(act, 0, -1):
		if ResourceLoader.exists(SCORE_PATH % n):
			return load(SCORE_PATH % n)
	return null

## Plays the career's act score in mix `m`.
func play_act(m: StringName) -> void:
	play_score(score_for(Career.act()), m)

## Plays `score` (crossfading from whatever played) and sets mix `m`. Starting
## from silence the levels apply at once, so no stem is heard that should not be.
func play_score(score: Score, m: StringName) -> void:
	var fresh := Music.score == null
	Music.play(score)
	set_mix(m, 0.0 if fresh else -1.0)

## Fades the playing score's stems to mix `m` over `time` (Music.fade_time if negative).
func set_mix(m: StringName, time := -1.0) -> void:
	mix = m
	if Music.score == null:
		return
	var levels := levels_for(Music.score, m)
	for id in levels:
		if not is_equal_approx(Music.level(id), levels[id]):
			Music.set_level(id, levels[id], time)

## Stem id -> dB for mix `m` of `score`.
static func levels_for(score: Score, m: StringName) -> Dictionary:
	var on: Array = MIXES.get(m, ALL)
	var out := {}
	for s in score.stems:
		out[s.id] = s.level_db if (on == ALL or s.id in on) else Music.SILENT_DB
	return out

## The job board: the act's score, drone and pad.
func board() -> void:
	play_act(&"board")

## Follows `runner`'s states from now on.
func watch(runner: JobRunner) -> void:
	var follow := _on_state.bind(runner)
	if not runner.state_changed.is_connected(follow):
		runner.state_changed.connect(follow)

func _on_state(s: JobRunner.State, _previous: JobRunner.State, runner: JobRunner) -> void:
	if not runner.pays_out:
		return
	play_act(STATE_MIX[s])
