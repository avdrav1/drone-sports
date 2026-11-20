---
name: ship-it
description: Run tests, export the Godot web build, and deploy it to GitHub Pages and itch.io. Use only when asked to ship or deploy.
disable-model-invocation: true
argument-hint: "[--skip-tests]"
allowed-tools: Bash(scripts/ship.sh *) Bash(scripts/itch.sh *) Bash(git fetch *) Bash(git rev-list *) Bash(scripts/test.sh *) Bash(git status *) Bash(git log *) Bash(ls build/*)
---

## Working tree

!`git status --short 2>/dev/null | head -20 || true`

## Task

Ship the current build to GitHub Pages and itch.io.

1. If the working tree above has uncommitted changes, say so and ask whether to continue. Shipping uncommitted work is allowed but should be deliberate.
2. Run `git fetch -q origin && git rev-list --count HEAD..origin/main`. If it prints anything but `0`, the local branch is missing work that is already on origin; shipping it would wipe that work off the live site. Say so and stop.
3. Run `scripts/ship.sh $ARGUMENTS`. It runs tests (unless `--skip-tests`), exports the Web preset to `build/web/`, copies `web/CNAME` into it, force-pushes it as one commit to the `gh-pages` branch of `origin`, turns on GitHub Pages for that branch the first time, and sets the custom domain (`jaisalmergame.com`) and HTTPS. "HTTPS not enforced yet" is expected until GitHub has issued the domain's certificate.
4. If `web/ITCH_TARGET` exists, run `scripts/itch.sh --skip-tests` (tests already ran in step 3). It exports the Web preset to `build/itch/` and runs `butler push` to `<web/ITCH_TARGET>:html5`. If `web/ITCH_TARGET` is missing, skip this step and say itch.io was skipped.
5. If a script fails, read the error and map it to one of these before trying anything else:
   - `godot: command not found` → set `GODOT_BIN` to the editor binary path, or install Godot 4.3+ and add it to PATH.
   - `No export template found` → in the Godot editor open Editor > Manage Export Templates and download the templates for this version. Do not try to download them from the shell.
   - `no origin remote` → the repo has no GitHub remote. Ask the user before creating one.
   - Push rejected or `gh` auth errors → the user runs `gh auth login` themselves. Do not attempt it.
   - butler `invalid game` or 404 → the game page does not exist on itch.io yet, or `web/ITCH_TARGET` has the wrong `user/game`. The user creates the page (Kind of project: HTML) on itch.io.
   - butler auth errors → the user runs `butler login` themselves. Do not attempt it.
   If `ship.sh` fails, do not run `itch.sh`. If only `itch.sh` fails, GitHub Pages is already live; report that.
6. On success, report the deployment URL the script printed, the itch.io build butler reported (or that itch was skipped), and the commit it was built from. The first Pages build can take a minute to go live. Nothing else.

Never edit `export_presets.cfg` or `web/_headers` from this skill. If they look wrong, say so and stop.
