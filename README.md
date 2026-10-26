# Drone Sports

A near-future drone-piloting game built in Godot 4 with Claude Code. See `docs/VISION.md` for the design, `docs/CHARACTERS.md` for the cast, `docs/BOSS.md` for the ending, and `docs/BACKLOG.md` for the stories.

## One-time setup

1. Install Godot 4.3+ and put the binary on your PATH as `godot`, or set `GODOT_BIN=/path/to/godot`.
2. Open the project once in the editor and download the Web export templates (Editor > Manage Export Templates).
3. Install Node 18+ (wrangler runs through `npx`).
4. Sign in to Cloudflare and create the Pages project:
   ```
   npx wrangler login
   npx wrangler pages project create drone-sports --production-branch main
   ```
   To use a different project name, set `CF_PAGES_PROJECT`.
5. `git init && git add . && git commit -m "Scaffold"`

## Daily loop

Open Claude Code in this folder and run:

| Command | What it does |
| --- | --- |
| `/next-story` | Implements the first unchecked story in `docs/BACKLOG.md`, runs tests, ticks it, commits |
| `/next-story 1.3` | Same, but for a specific story |
| `/ship-it` | Runs tests, exports the web build, deploys to Cloudflare Pages |
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
