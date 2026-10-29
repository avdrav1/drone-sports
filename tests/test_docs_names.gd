extends RefCounted
# Story 25.4: the docs and the rules use the new cast and Ravana. No .md file
# outside the backlog names a character by an old name or calls the boss the
# Lattice, outside `code` spans (ids, paths and class names keep their spelling
# until Story 25.2). CLAUDE.md rule 9 names Ravana and keeps the boss
# disable-only, and the docs give the cast no he or she.

const NAMES = preload("res://tests/test_new_names.gd")
## The backlog keeps its history.
const SKIPPED := ["res://docs/BACKLOG.md"]
## Folders that are not the repo's own docs.
const NOT_REPO := [".godot", ".git", ".worktrees", "build"]
const CAST_DOCS := ["res://docs/CHARACTERS.md", "res://docs/BOSS.md", "res://docs/VISION.md"]

func _docs(dir: String, out: Array[String]) -> Array[String]:
	var d := DirAccess.open(dir)
	d.include_hidden = true
	for sub in d.get_directories():
		if sub not in NOT_REPO:
			_docs(dir.path_join(sub), out)
	for file in d.get_files():
		var path := dir.path_join(file)
		if file.get_extension() == "md" and path not in SKIPPED:
			out.append(path)
	return out

## `line` with its `code` spans cut out: what a reader takes as words.
static func prose(line: String) -> String:
	return RegEx.create_from_string("`[^`]*`").sub(line, "", true)

## True if `s` names the boss by its old name.
static func has_lattice(s: String) -> bool:
	return RegEx.create_from_string("(?i)(?<![a-z0-9])lattice(?![a-z0-9])").search(s) != null

func test_no_doc_uses_an_old_name() -> bool:
	var bad := []
	var docs := _docs("res://", [] as Array[String])
	for path in docs:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var s := prose(lines[i])
			if NAMES.has_old_name(s) or has_lattice(s):
				bad.append("%s:%d" % [path, i + 1])
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty() and "res://docs/CHARACTERS.md" in docs and "res://CLAUDE.md" in docs

## The scan reads past code spans and still catches names in prose.
func test_the_scan_skips_code_and_catches_names() -> bool:
	return not NAMES.has_old_name(prose("| `marlo` | Sanjaya | Spotter |")) \
		and not has_lattice(prose("`data/boss/lattice.tres` has `enabled`")) \
		and NAMES.has_old_name(prose("Marlo and `bea` are in the field")) \
		and has_lattice(prose("the job board shows the Lattice"))

func test_the_cast_doc_names_everyone() -> bool:
	var doc := FileAccess.get_file_as_string("res://docs/CHARACTERS.md")
	var ok := true
	for id in NAMES.NAMES:
		var c: Character = load("res://data/characters/%s.tres" % id)
		ok = ok and NAMES.NAMES[id] in doc and c.name in doc
	return ok and "Ravana" in FileAccess.get_file_as_string("res://docs/BOSS.md") \
		and "Ravana" in FileAccess.get_file_as_string("res://docs/VISION.md")

func test_rule_9_names_ravana_and_stays_disable_only() -> bool:
	var rule := ""
	for line in FileAccess.get_file_as_string("res://CLAUDE.md").split("\n"):
		if line.begins_with("9. "):
			rule = line
	return rule.begins_with("9. The boss (Ravana) is a job like any other.") \
		and "disabled, never destroyed" in rule and "no explosions" in rule \
		and "no destruction objective" in rule and "`enabled`" in rule

## Characters have no stated pronouns: the docs about them use names or "they".
func test_cast_docs_give_no_he_or_she() -> bool:
	var re := RegEx.create_from_string("(?i)\\b(he|she|him|her|hers|his)\\b")
	var bad := []
	for path in CAST_DOCS:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			bad.append("%s: %s" % [path, m.get_string()])
	if not bad.is_empty():
		print("        ", bad)
	return bad.is_empty()
