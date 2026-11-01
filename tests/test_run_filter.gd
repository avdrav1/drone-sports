extends RefCounted
# The runner's ONLY filter, which scripts/test.sh also uses to split a full run.

const Runner := preload("res://tests/run.gd")
const FILES: PackedStringArray = ["test_song_a.gd", "test_song_b.gd", "test_zoo.gd", "sim.gd", "test_zoo.gd.uid"]

func test_no_filter_picks_every_test_file_and_nothing_else() -> bool:
	var picked: Dictionary = Runner.select(FILES, "")
	return picked.files == PackedStringArray(["test_song_a.gd", "test_song_b.gd", "test_zoo.gd"]) and picked.unmatched.is_empty()

func test_names_and_wildcards_pick_their_files_once() -> bool:
	var picked: Dictionary = Runner.select(FILES, "test_zoo, test_song_*,test_song_a")
	return picked.files == PackedStringArray(["test_song_a.gd", "test_song_b.gd", "test_zoo.gd"]) and picked.unmatched.is_empty()

func test_a_name_that_matches_nothing_is_reported() -> bool:
	var picked: Dictionary = Runner.select(FILES, "test_zoo,test_typo")
	return picked.files == PackedStringArray(["test_zoo.gd"]) and picked.unmatched == PackedStringArray(["test_typo"])
