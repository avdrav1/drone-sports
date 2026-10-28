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
# A runner's job plays the act it is flown in (act_for), so a fleet job, whose
# assists are Act 5's, plays act_5. In Act 5 (Story 16.7) a CommandView hands
# itself to command(): of the choir stems only the one sized nearest the fleet
# sounds, and while a drone is flown by hand the lead voice comes forward.
# Tension (Story 16.8): while any source (a HazardZone warning, a HazardScene
# collapse) holds tense(), every stem but the drone and the pulse falls away,
# whatever the mix; when the last lets go the mix comes back.
# Crew motifs (Story 16.10): a stem named by a character's `motif` sounds only
# while Roster has them active, INJURED_DB lower while injured, and is silent
# for good once they are dead (CLAUDE.md rule 7: nothing brings it back).
# The Lattice (Story 16.11): a LatticeFight hands itself to lattice(), and its
# runner plays data/music/lattice.tres instead of an act score. Of its choir
# densities the ones nearest the fraction of gap units reclaimed sound (dense
# at none, sparse at all), during the override only the lone voice and the
# drone are left, and once the boss is disabled every stem falls silent. With
# the boss disabled in data/boss/lattice.tres the score is never loaded.

const SCORE_PATH := "res://data/music/act_%d.tres"
## Stems that sound in each mix; ALL means every stem in the score.
const ALL := [&"*"]
## From Act 2 the harmonium (`reed`) has the pad's place and the tanpura's
## plucked arpeggio (`pluck`) the arpeggio's; a score sounds the ones it has.
const MIXES := {
	&"board": [&"drone", &"pad", &"reed"],
	&"briefing": [&"drone", &"pad", &"reed"],
	&"countdown": [&"drone", &"pad", &"arp", &"reed", &"pluck"],
	&"live": ALL,
	&"results": [&"drone", &"pad", &"reed"],
	&"tension": [&"drone", &"pulse"],
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

## Act 5's answer choirs: fleet size -> the stem baked at that many voices.
const CHOIRS := {3: &"choir_3", 10: &"choir_10", 50: &"choir_50"}
## The call's lead voice, and how far it comes forward while a drone is flown.
const LEAD := &"mantra_lead"
const LEAD_FORWARD_DB := 6.0
## How far below its level an injured crew member's motif plays.
const INJURED_DB := 9.0
## The Lattice's score, its choir densities from densest to sparsest, and the
## stems the override hold leaves.
const LATTICE_PATH := "res://data/music/lattice.tres"
const DENSITIES := [&"density_4", &"density_3", &"density_2", &"density_1"]
const HOLD := [&"drone", &"voice"]

## The mix last set.
var mix: StringName = &""
## The fleet layer in use, or null.
var fleet: CommandView
## The Lattice fight in play, or null; and whether it has disabled the boss.
var boss_fight: LatticeFight
var boss_off := false
var _tension := {}  # instance id of each source holding tension -> true

func _ready() -> void:
	Roster.status_changed.connect(func(_id, _status): _on_fleet())

## The score for `act`: its own, or the nearest earlier act's. Null if none.
func score_for(act: int) -> Score:
	for n in range(act, 0, -1):
		if ResourceLoader.exists(SCORE_PATH % n):
			return load(SCORE_PATH % n)
	return null

## The act `job` is flown in: its assists' act or the career's, whichever is
## later (as the board shows it).
static func act_for(job: Job) -> int:
	var job_act := int(job.required_assists.label.trim_prefix("Act ")) if job and job.required_assists else 1
	return maxi(job_act, Career.act())

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
	var levels := crew_levels(command_levels(levels_for(Music.score, &"tension" if tense() else m), fleet_size(), flying()))
	levels = boss_levels(levels, reclaimed_fraction(), holding(), boss_off and is_instance_valid(boss_fight))
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

## Drones under command in the fleet layer, 0 without one.
func fleet_size() -> int:
	return fleet.drones.size() if is_instance_valid(fleet) and fleet.is_inside_tree() else 0

## A fleet drone is being flown by hand.
func flying() -> bool:
	return is_instance_valid(fleet) and fleet.is_inside_tree() and fleet.flown != null

## The choir stem for a fleet of `n` drones: the size nearest it (by ratio).
static func choir_for(n: int) -> StringName:
	var best: int = CHOIRS.keys()[0]
	for size in CHOIRS:
		if absf(log(maxf(n, 1.0) / size)) < absf(log(maxf(n, 1.0) / best)):
			best = size
	return CHOIRS[best]

## `levels` with only the choir for `size` drones left sounding of the choirs
## the mix has on, and the lead `LEAD_FORWARD_DB` up when `forward`. Scores
## without choirs or a lead are unchanged.
static func command_levels(levels: Dictionary, size: int, forward: bool) -> Dictionary:
	var choir := choir_for(size)
	for id in CHOIRS.values():
		if levels.has(id) and id != choir:
			levels[id] = Music.SILENT_DB
	if forward and levels.has(LEAD) and levels[LEAD] > Music.SILENT_DB:
		levels[LEAD] += LEAD_FORWARD_DB
	return levels

## `levels` with each crew member's motif as Roster has them: as it is while
## active, INJURED_DB down while injured, silent once dead.
static func crew_levels(levels: Dictionary) -> Dictionary:
	for id in Roster.characters:
		var motif: StringName = Roster.characters[id].motif
		if motif == &"" or not levels.has(motif):
			continue
		match Roster.status(id):
			Roster.Status.DEAD:
				levels[motif] = Music.SILENT_DB
			Roster.Status.INJURED:
				if levels[motif] > Music.SILENT_DB:
					levels[motif] = maxf(levels[motif] - INJURED_DB, Music.SILENT_DB)
	return levels

## The Lattice's score, or null when the boss is disabled (then it is never
## loaded). Each load is recorded in BossGate.loads.
static func lattice_score() -> Score:
	if not BossGate.listed():
		return null
	BossGate.loads.append(LATTICE_PATH)
	return load(LATTICE_PATH)

## Follows `fight`, the Lattice: reclaimed units, the override and the boss
## going off change the mix.
func lattice(fight: LatticeFight) -> void:
	boss_fight = fight
	boss_off = false
	if not fight.unit_reclaimed.is_connected(_on_reclaimed):
		fight.unit_reclaimed.connect(_on_reclaimed)
	if not fight.phase_started.is_connected(_on_fleet):
		fight.phase_started.connect(_on_fleet)
	# A lost fleet drone gives its unit back after the signal; look once it has.
	if not fight.fleet_drone_lost.is_connected(_on_fleet):
		fight.fleet_drone_lost.connect(_on_fleet, CONNECT_DEFERRED)
	if not fight.boss_disabled.is_connected(_on_boss_disabled):
		fight.boss_disabled.connect(_on_boss_disabled)

func _on_reclaimed(_unit: int, _by: Drone) -> void:
	_on_fleet()

func _on_boss_disabled() -> void:
	boss_off = true
	_on_fleet()

## The share of the gap units reclaimed, 0..1; 0 without a fight.
func reclaimed_fraction() -> float:
	if not is_instance_valid(boss_fight) or boss_fight.lattice == null or boss_fight.boss() == null:
		return 0.0
	return clampf(float(boss_fight.reclaimed.size()) / maxi(boss_fight.boss().gap_units, 1), 0.0, 1.0)

## The fight is at the override port.
func holding() -> bool:
	return is_instance_valid(boss_fight) and boss_fight.phase == LatticeFight.Phase.OVERRIDE

## `levels` for the Lattice's score: the DENSITIES crossfaded (equal power) by
## `fraction` reclaimed, densest at 0 and sparsest at 1; only HOLD while
## `hold`; every stem silent once `off`. Scores without the densities are
## unchanged.
static func boss_levels(levels: Dictionary, fraction: float, hold: bool, off: bool) -> Dictionary:
	if not DENSITIES.all(func(id): return levels.has(id)):
		return levels
	var at := clampf(fraction, 0.0, 1.0) * (DENSITIES.size() - 1)
	for i in DENSITIES.size():
		var id: StringName = DENSITIES[i]
		var w := cos(absf(at - i) * PI / 2.0) if absf(at - i) < 1.0 else 0.0
		if w < 0.001 or levels[id] <= Music.SILENT_DB:
			levels[id] = Music.SILENT_DB
		else:
			levels[id] = maxf(levels[id] + linear_to_db(w), Music.SILENT_DB)
	for id in levels:
		if off or (hold and not id in HOLD):
			levels[id] = Music.SILENT_DB
	return levels

## Follows `view`, the fleet layer: its size and drops into a drone change the mix.
func command(view: CommandView) -> void:
	fleet = view
	for sig in [view.dropped_in, view.left, view.fleet_changed]:
		if not sig.is_connected(_on_fleet):
			sig.connect(_on_fleet)

func _on_fleet(_arg = null) -> void:
	if mix != &"":
		set_mix(mix)

## `source` raises (`on`) or lets go of tension. Freed sources let go.
func set_tension(source: Object, on: bool) -> void:
	var was := tense()
	if on:
		_tension[source.get_instance_id()] = true
	else:
		_tension.erase(source.get_instance_id())
	if tense() != was and mix != &"":
		set_mix(mix)

## Something holds tension: only the drone and the pulse play.
func tense() -> bool:
	for id in _tension.keys():
		if not is_instance_id_valid(id):
			_tension.erase(id)
	return not _tension.is_empty()

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
	var fights := is_instance_valid(boss_fight) and boss_fight.runner == runner
	play_score(lattice_score() if fights else score_for(act_for(runner.job)), STATE_MIX[s])
