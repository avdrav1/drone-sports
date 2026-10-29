# Jaisalmer

A near-future drone-piloting game built in Godot 4 with Claude Code. See `docs/VISION.md` for the design, `docs/CHARACTERS.md` for the cast, `docs/BOSS.md` for the ending, and `docs/BACKLOG.md` for the stories.

## One-time setup

1. Install Godot 4.3+ and put the binary on your PATH as `godot`, or set `GODOT_BIN=/path/to/godot`.
2. Open the project once in the editor and download the Web export templates (Editor > Manage Export Templates).
3. Install the GitHub CLI and sign in with `gh auth login`. The repo needs an `origin` remote on GitHub you can push to.

## Deploy

`scripts/ship.sh` deploys to GitHub Pages:

1. Runs `scripts/test.sh` (skip with `--skip-tests`).
2. Exports the Web preset to `build/web/` and adds `.nojekyll`.
3. Force-pushes `build/web/` as one fresh commit to the `gh-pages` branch of `origin` (set `PAGES_BRANCH` to use another branch). The branch keeps no history.
4. Turns on GitHub Pages for that branch through `gh api` the first time, and prints the site's URL.

The first Pages build can take a minute to go live.

## Daily loop

Open Claude Code in this folder and run:

| Command | What it does |
| --- | --- |
| `/next-story` | Implements the first unchecked story in `docs/BACKLOG.md`, runs tests, ticks it, commits |
| `/next-story 1.3` | Same, but for a specific story |
| `/ship-it` | Runs tests, exports the web build, deploys to GitHub Pages |
| `/ship-it --skip-tests` | Deploys without the test gate |

Both skills are user-invoked only; Claude will not run them on its own.

## Manual commands

```
scripts/test.sh                # headless tests
scripts/ship.sh                # export + deploy
godot --path . --editor        # open the editor
```

## Layout

See the Layout section in `CLAUDE.md`. Short version: `scenes/` for `.tscn`, `scripts/` for `.gd`, `data/` for `.tres`, `tests/` for `test_*.gd`.
