---
name: ship-it
description: Run tests, export the Godot web build, and deploy it to GitHub Pages. Use only when asked to ship or deploy.
disable-model-invocation: true
argument-hint: "[--skip-tests]"
allowed-tools: Bash(scripts/ship.sh *) Bash(scripts/test.sh *) Bash(git status *) Bash(git log *) Bash(ls build/*)
---

## Working tree

!`git status --short 2>/dev/null | head -20 || true`

## Task

Ship the current build to GitHub Pages.

1. If the working tree above has uncommitted changes, say so and ask whether to continue. Shipping uncommitted work is allowed but should be deliberate.
2. Run `scripts/ship.sh $ARGUMENTS`. It runs tests (unless `--skip-tests`), exports the Web preset to `build/web/`, force-pushes it as one commit to the `gh-pages` branch of `origin`, and turns on GitHub Pages for that branch the first time.
3. If the script fails, read the error and map it to one of these before trying anything else:
   - `godot: command not found` → set `GODOT_BIN` to the editor binary path, or install Godot 4.3+ and add it to PATH.
   - `No export template found` → in the Godot editor open Editor > Manage Export Templates and download the templates for this version. Do not try to download them from the shell.
   - `no origin remote` → the repo has no GitHub remote. Ask the user before creating one.
   - Push rejected or `gh` auth errors → the user runs `gh auth login` themselves. Do not attempt it.
4. On success, report the deployment URL the script printed and the commit it was built from. The first Pages build can take a minute to go live. Nothing else.

Never edit `export_presets.cfg` or `web/_headers` from this skill. If they look wrong, say so and stop.
