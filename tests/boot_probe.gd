extends SceneTree
# Run in its own process by test_music_lattice.gd: boots the project (autoloads
# only, no scene) and prints, for each path given after `--`, whether it is in
# the resource cache after the first frames, and whether MusicDirector booted
# (so a director that fails to compile cannot pass for one that loads nothing).

var _frames := 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	print("director %s" % (root.get_node_or_null("MusicDirector") != null))
	for p in OS.get_cmdline_user_args():
		print("cached %s %s" % [p, ResourceLoader.has_cached(p)])
	quit()
	return false
