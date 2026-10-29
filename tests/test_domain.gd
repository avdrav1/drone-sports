extends RefCounted
# Story 24.4: the game is served from jaisalmergame.com. The domain lives in a
# checked-in web/CNAME, scripts/ship.sh copies it into every deploy and sets
# the Pages domain from it, and the build uses only relative paths, so moving
# from /drone-sports/ to / breaks nothing. DNS and HTTPS are the owner's checks.

const DOMAIN := "jaisalmergame.com"
const CNAME := "res://web/CNAME"
const SHIP := "res://scripts/ship.sh"
const PRESETS := "res://export_presets.cfg"
## The last export, if one has been made here (build/ is gitignored).
const BUILT := "res://build/web/index.html"

func test_cname_holds_exactly_the_domain() -> bool:
	return FileAccess.file_exists(CNAME) and FileAccess.get_file_as_string(CNAME) == DOMAIN

func test_ship_copies_cname_into_the_deploy() -> bool:
	var ship := FileAccess.get_file_as_string(SHIP)
	var copy := ship.find("cp web/CNAME \"$OUT/CNAME\"")
	# After the export (which empties the folder) and before the push.
	return copy > ship.find("--export-release") and copy < ship.find("push -q --force") \
		and ship.find("--export-release") > ship.find("rm -rf \"$OUT\"")

func test_ship_sets_the_domain_and_prints_it() -> bool:
	var ship := FileAccess.get_file_as_string(SHIP)
	return "DOMAIN=\"$(tr -d '[:space:]' < web/CNAME)\"" in ship \
		and "-f \"cname=$DOMAIN\"" in ship and "https_enforced=true" in ship \
		and "echo \"Deployed: https://$DOMAIN/\"" in ship and "html_url" not in ship \
		and "github.io" not in ship

## No absolute or site-specific path in what the export is made from: the
## default HTML shell (which loads index.js, index.pck and index.wasm by
## relative name), no head include, and no /drone-sports/ prefix anywhere.
func test_the_export_uses_relative_paths() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PRESETS) != OK:
		return false
	var ok: bool = cfg.get_value("preset.0", "export_path") == "build/web/index.html" \
		and cfg.get_value("preset.0.options", "html/custom_html_shell") == "" \
		and cfg.get_value("preset.0.options", "html/head_include") == ""
	for f in [PRESETS, "res://project.godot"]:
		ok = ok and "drone-sports/" not in FileAccess.get_file_as_string(f)
	if FileAccess.file_exists(BUILT):
		ok = ok and absolute_refs(FileAccess.get_file_as_string(BUILT)).is_empty()
	return ok

## Every src or href in `html` that is not relative to the page.
static func absolute_refs(html: String) -> Array:
	var out := []
	for m in RegEx.create_from_string("(?:src|href)=\"([^\"]*)\"").search_all(html):
		var url := m.get_string(1)
		if url.begins_with("/") or "://" in url:
			out.append(url)
	return out

func test_absolute_refs_catches_rooted_paths() -> bool:
	return absolute_refs("<script src=\"index.js\"></script><link href=\"index.icon.png\">").is_empty() \
		and absolute_refs("<script src=\"/drone-sports/index.js\"></script>") == ["/drone-sports/index.js"] \
		and absolute_refs("<link href=\"https://x.io/a.css\">") == ["https://x.io/a.css"]
