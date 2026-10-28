extends RefCounted
# Story 5.1: teams and factions. Six teams across three factions load and
# validate, each takes only job types some job has, and each grants a preset.

const LIST := "res://data/teams/teams.tres"

## Every job type used by a job in data/jobs.
func _job_types() -> Array:
	var out := []
	for f in DirAccess.get_files_at("res://data/jobs"):
		var path := "res://data/jobs/" + f.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var r := load(path)
		if r is Job and r.job_type != &"" and not r.job_type in out:
			out.append(r.job_type)
	return out

func test_six_teams_three_factions_validate() -> bool:
	var list: TeamList = load(LIST)
	var types := _job_types()
	var ok: bool = list != null and list.teams.size() == 6
	var ids := []
	for t in list.teams:
		var problems := t.validate(types)
		for p in problems:
			print("        " + p)
		ok = ok and problems.is_empty() and not t.id in ids and list.by_id(t.id) == t
		ids.append(t.id)
	for f in Team.FACTIONS:
		ok = ok and list.in_faction(f).size() == 2
	return ok

func test_teams_cover_every_job_type() -> bool:
	var list: TeamList = load(LIST)
	var covered := []
	for t in list.teams:
		covered.append_array(t.job_types)
	var ok := true
	for t in _job_types():
		ok = ok and t in covered
	return ok and _job_types().size() >= 5

func test_presets_step_through_the_acts() -> bool:
	var list: TeamList = load(LIST)
	var ok := true
	for f in Team.FACTIONS:
		var teams := list.in_faction(f)
		# The easier team in each faction asks less and leaves more assists on.
		teams.sort_custom(func(a, b): return a.reputation_needed < b.reputation_needed)
		var first: String = teams[0].preset.label
		var second: String = teams[1].preset.label
		ok = ok and first < second and first in ["Act 2", "Act 3"] and second in ["Act 3", "Act 4"]
	# The league's first team is the one Coach Rin scouts for: it asks for nothing.
	return ok and list.by_id(&"skyline_juniors").reputation_needed == 0 \
		and list.by_id(&"skyline_juniors").preset.label == "Act 2"

func test_validate_catches_bad_data() -> bool:
	var t := Team.new()
	t.id = &"bad"
	t.name = "Bad"
	t.faction = &"navy"
	t.job_types = [&"arena"]
	var problems := t.validate([&"race"])
	var text := "\n".join(problems)
	return text.contains("unknown faction") and text.contains("no job of type arena") and text.contains("no assist preset")

func test_job_factions_are_known() -> bool:
	var ok := true
	for f in DirAccess.get_files_at("res://data/jobs"):
		var r := load("res://data/jobs/" + f.trim_suffix(".remap")) if f.ends_with(".tres") else null
		if r is Job:
			ok = ok and r.faction in Team.FACTIONS
	return ok
