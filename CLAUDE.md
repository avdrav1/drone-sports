# Drone Sports

A near-future drone-piloting game. You start as a gamer, get scouted by a team, and climb from single-drone jobs to fleet command. One flight model runs the whole game; progression removes assists, never changes physics.

## Stack

- Engine: Godot 4.3+, GDScript, Forward+ on desktop, GL Compatibility on web
- Tests: `scripts/test.sh` (headless; `tests/run.gd` runs every `tests/test_*.gd`)
- Deploy: `scripts/ship.sh` exports the Web preset and pushes to Cloudflare Pages
- No addons unless a story asks for one

## Layout

```
scenes/     .tscn files, one folder per system (drone/, jobs/, ui/)
scripts/    .gd files that back scenes, plus shell scripts
data/       .tres resources: assist stacks, jobs, teams, courses, characters, dialogue, boss
tests/      test_*.gd, each method starting with test_ returns true or false
docs/       VISION.md, CHARACTERS.md, BOSS.md, BACKLOG.md
web/        files copied into the web build (_headers)
build/      export output, gitignored
```

## Design rules

1. There is exactly one flight model: `scenes/drone/drone.tscn` driven by four motor thrusts on a RigidBody3D. Nothing else moves a drone.
2. Assists sit in a pipeline in front of the mixer and rewrite an `Intent` struct. They never touch physics code.
3. Jobs are scenes that plug into `JobRunner`. The framework holds no job-specific code.
4. Data over code: assist stacks, jobs, teams, and courses are `.tres` resources in `data/`.
5. Upgrades change exported drone stats. They never add or remove assists.
6. Characters are data in `data/characters/`. Their status (active, injured, dead) lives in the save file. No scene hard-codes a character.
7. A crew member is only at risk on a job that declares `crew_in_field` and places a `HazardZone`, after a visible warning. Death is permanent. Never add a way to revive.
8. The camera is a tool for flying, not a mechanic. Views are chase, FPV, orbit, and top-down; nothing is ever graded on what the camera sees.
9. The boss (the Lattice) is a job like any other. It is disabled, never destroyed: no explosions, no destruction objective. `data/boss/lattice.tres` has `enabled`; when false, nothing about the boss loads or appears. Its design is original; do not reference or imitate existing franchises in names, art, or lines.

## Assist presets by act

| Assist | On until | Removing it unlocks |
| --- | --- | --- |
| Collision guard | Act 2 | Tight gaps, interior flying |
| Altitude hold | Act 3 | Dives, low passes |
| Auto-level | Act 3 | Banked turns, dutch angles |
| Speed governor | Act 4 | Full throttle, top speed |
| Battery and wind sim | Act 4 | Route planning, timing to gusts |
| Single-drone view | Act 5 | Fleet command layer |

## Story workflow

- Stories live in `docs/BACKLOG.md` as checkboxes. Work them in order unless told otherwise.
- `/next-story` picks the first unchecked story, implements it, runs tests, ticks the box, commits.
- `/ship-it` runs tests, exports the web build, deploys to Cloudflare Pages.
- One story per commit. Commit message: `Story X.Y: <title>`.
- Every story adds or extends a test in `tests/`. A story is not done until `scripts/test.sh` passes.
- Keep diffs small. Do not refactor outside the story's scope.
- When a story's acceptance criteria cannot be met as written, stop and say why instead of changing the criteria.
