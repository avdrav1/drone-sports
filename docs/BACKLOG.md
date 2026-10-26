# Drone Sports: Backlog

Stories for `/next-story`. Work them top to bottom. Epics 0 to 3 are sequential; 4, 5, and 7 can run in parallel after 3 (do 7.1 to 7.3 before 5.3, since the job board shows the roster); 6 waits for playtesting; 8 waits for 6 and 7.

Each story: **Goal** (what exists when done), **Context** (what it builds on), **Acceptance** (checkable; every item gets a test), **Out of scope**.

Tick a story only after `scripts/test.sh` passes.

---

## Epic 0: Project scaffold

Done when Claude Code can open the repo, read CLAUDE.md, and run tests headless.

- [x] **0.1 Create the repo and CLAUDE.md**
  - Goal: An empty Godot 4 project with a CLAUDE.md describing the game, the stack, and how to test.
  - Context: Greenfield. Delivered by the scaffold package.
  - Acceptance: Project opens in Godot 4 with no errors. CLAUDE.md names the engine, language, layout, and test command.
  - Out of scope: Any gameplay.

- [x] **0.2 Test harness**
  - Goal: A headless test runner Claude Code can call after every story.
  - Context: `tests/run.gd` and `scripts/test.sh`, delivered by the scaffold.
  - Acceptance: `scripts/test.sh` runs all tests and exits nonzero on failure. One trivial passing test exists.
  - Out of scope: CI.

- [x] **0.3 Debug flight scene**
  - Goal: A sandbox scene with a flat ground plane, a few boxes, a free camera, and an on-screen readout of position, velocity, and active assists.
  - Context: Every later story is played by hand here. Save as `scenes/debug_flight.tscn` and set it as the main scene in `project.godot`. Keep it ugly and fast.
  - Acceptance: Scene loads headless without errors. Readout node updates every frame. The `toggle_readout` action (F1) toggles readout visibility. A test instantiates the scene and checks the readout node exists.
  - Out of scope: Art, lighting, menus.

## Epic 1: One flight model with a toggleable assist stack

Done when a quadcopter flies with real physics in the debug scene and each assist can be switched on or off at runtime without changing the physics code.

- [x] **1.1 Quadcopter rigid body**
  - Goal: `scenes/drone/drone.tscn` whose motion comes from four thrust values applied to a RigidBody3D.
  - Context: The only flight model in the game. Every assist sits in front of it, never inside it. Script at `scripts/drone/drone.gd`.
  - Acceptance: With all thrust at hover value the drone holds within 0.1 m of its start height for 10 s of physics ticks. Unequal thrust produces pitch, roll, and yaw in the expected directions. Mass, drag, and max thrust are `@export` variables. A test steps physics and checks hover and each rotation axis.
  - Out of scope: Input, assists, wind, battery.

- [ ] **1.2 Raw stick input**
  - Goal: Gamepad and keyboard input mapped to throttle, pitch, roll, yaw, with a mixer that turns them into four motor thrusts.
  - Context: Builds on 1.1. Input fills an `Intent` resource (`scripts/drone/intent.gd`) so assists can rewrite it before the mixer. Input actions are already defined in `project.godot`.
  - Acceptance: Full throttle climbs, zero throttle falls, sticks map to the correct rotations. Mixer is a pure function and unit tested with known inputs.
  - Out of scope: Assists, camera.

- [ ] **1.3 Assist pipeline**
  - Goal: An ordered list of `Assist` nodes, each able to read drone state and rewrite `Intent` before the mixer, with an `enabled` flag on each.
  - Context: The progression system's hook. `scripts/drone/assist.gd` base class; `AssistStack` resource (`scripts/drone/assist_stack.gd`) lists which assists are on.
  - Acceptance: Pipeline runs assists in order every physics frame. A disabled assist is skipped. Debug readout shows the stack. Test: a stub assist that zeroes pitch is honored when on, ignored when off.
  - Out of scope: Any real assist.

- [ ] **1.4 Collision guard**
  - Goal: An assist that stops the drone before it hits something.
  - Context: First assist, the one players lose first. Uses raycasts or a shape cast ahead of the velocity vector.
  - Acceptance: Flying at a wall at 10 m/s stops within 1 m of it with no contact. Does not alter intent when nothing is ahead. Can be disabled live.
  - Out of scope: Pathing around obstacles.

- [ ] **1.5 Altitude hold and auto-level**
  - Goal: Two assists: one holds current height when throttle is centered, one levels the drone when pitch and roll sticks are released.
  - Context: Together these make the drone feel like an arcade flyer. Separately toggleable.
  - Acceptance: With both on, releasing all sticks returns the drone to level flight at constant height within 1 s. With auto-level off, bank angle persists. With altitude hold off, centered throttle sinks.
  - Out of scope: Terrain following.

- [ ] **1.6 Camera rig**
  - Goal: A `CameraRig` with four views the player cycles with the `cycle_camera` action (C): chase (behind and above, smoothed), FPV (on the nose, no smoothing), orbit (mouse or right stick swings around the drone), top-down (fixed height, follows). Each job can set a default view.
  - Context: The camera is a tool for flying, never a mechanic (CLAUDE.md rule 8). Chase and orbit must not clip through geometry: pull in on a shape cast.
  - Acceptance: Cycling order is chase, FPV, orbit, top-down, chase. FPV forward equals drone forward every frame. Chase camera never ends a frame inside a collider in a scripted wall-hug test. Job default view is honored on Briefing.
  - Out of scope: Replays, free-fly camera outside debug.

- [ ] **1.6a Speed governor**
  - Goal: An assist that caps horizontal speed at a configured value and softens throttle response near the cap.
  - Context: Fourth assist in the act table. Rewrites `Intent` only; never touches the mixer.
  - Acceptance: With it on, full stick holds at the cap within 5 percent. With it off, the same input exceeds the cap. Can be disabled live.
  - Out of scope: Per-job caps.

- [ ] **1.7 Battery and wind**
  - Goal: An environment assist that, when off, applies a wind vector and drains a battery; when on, both are disabled.
  - Context: Last assist to come off. Wind is a per-scene resource with a base vector and gust amplitude.
  - Acceptance: With the assist off, the drone drifts in wind unless corrected and the battery reaches zero after the configured flight time, after which thrust fades over 3 s. With it on, neither happens.
  - Out of scope: Weather visuals.

- [ ] **1.8 Assist presets by act**
  - Goal: Five `AssistStack` resources in `data/assists/` matching the table in CLAUDE.md (collision guard, altitude hold, auto-level, speed governor, battery and wind, single-drone view), plus a settings toggle that overrides to all-off.
  - Context: Closes the epic. Epic 5 swaps these; for now the `cycle_preset` action (F2) cycles them in the debug scene.
  - Acceptance: F2 cycles Act 1 to Act 5 presets and the readout shows the change. An "Expert: all assists off" setting overrides the preset. Test loads all five resources and checks each matches the table.
  - Out of scope: Saving settings.

## Epic 2: Job framework, grading, and payout

Done when any scene can declare itself a job, run start to finish, produce a grade, and pay out, with no job-specific code in the framework.

- [ ] **2.1 Job resource and lifecycle**
  - Goal: A `Job` resource (id, title, client, required assist stack, time limit, pay) and a `JobRunner` node moving through Briefing, Countdown, Live, Complete, Failed.
  - Context: Every job type in Epics 3, 4, 6 plugs into this runner. `scripts/jobs/job.gd`, `scripts/jobs/job_runner.gd`.
  - Acceptance: Runner emits `state_changed` on each transition. Time limit ends the job as Failed. A test job with no objectives completes when `complete()` is called. Required assist stack is applied to the drone on Briefing.
  - Out of scope: UI beyond a text state label.

- [ ] **2.2 Objectives and graders**
  - Goal: An `Objective` base class with `score() -> float` in 0 to 1 and a `weight`, and a `Grader` that combines objectives into a grade A to F.
  - Context: Jobs add objectives as child nodes. Grade thresholds are data (A at 0.9, B at 0.75, C at 0.6, D at 0.4).
  - Acceptance: Two objectives at weights 2 and 1 scoring 1.0 and 0.0 grade to 0.67, a C. Unit tested.
  - Out of scope: Any concrete objective.

- [ ] **2.3 Common objectives**
  - Goal: Three reusable objectives: `ReachPoint`, `AvoidContact`, `FinishUnderTime`.
  - Context: Enough for a race and a delivery. Hazard objectives come in Epic 4.
  - Acceptance: Each has a test proving a passing and failing run. `AvoidContact` deducts per collision and floors at 0.
  - Out of scope: Combat objectives.

- [ ] **2.4 Payout and reputation**
  - Goal: `Wallet` and `Reputation` autoloads. Completing a job pays `pay * grade multiplier` and adds reputation with the client faction.
  - Context: Reputation gates Epic 5. Both are plain numbers saved to `user://save.json`.
  - Acceptance: An A pays 100 percent, a C pays 60 percent, an F pays 0 and costs 5 reputation. Values persist across a save and load.
  - Out of scope: Spending, upgrades.

- [ ] **2.5 Results screen**
  - Goal: A screen after each job listing every objective, its score, the grade, pay, and reputation change, with Retry and Continue.
  - Context: First real UI. One scene, one theme file in `scenes/ui/`.
  - Acceptance: Shows within 1 s of job end. Retry reloads the same job. Continue returns to the debug scene.
  - Out of scope: Leaderboards, replays.

## Epic 3: Race job

Done when a player can fly a gated race against AI drones with Act 1 assists, get graded, and get paid. This is the playable slice; stop and playtest here.

- [ ] **3.1 Gate and course**
  - Goal: A `Gate` node that detects a pass-through in the correct direction, and a `Course` that orders gates and tracks laps.
  - Context: Builds on `ReachPoint` from 2.3.
  - Acceptance: Passing a gate backwards does not count. Skipping a gate invalidates the lap. Course emits `lap_completed(time)`. A test course with 8 gates and 2 laps exists in `data/courses/`.
  - Out of scope: Course editor.

- [ ] **3.2 Race objectives**
  - Goal: `FinishPosition`, `CleanLap`, `BestSplit` objectives and a `RaceJob` scene wiring them to the course.
  - Context: Finish position weighted highest. Weights live in the Job resource.
  - Acceptance: First-place clean run grades A. Last place with contact grades no higher than D.
  - Out of scope: Multiplayer.

- [ ] **3.3 AI racers**
  - Goal: Three opponent drones that fly the course on a spline with speed noise and a small chance to clip a gate.
  - Context: Same `Drone` scene with a scripted `Intent` source instead of input, so physics match the player.
  - Acceptance: Opponents finish within 10 percent of each other on the test course. They never leave course bounds. Lap times reproducible with a seed.
  - Out of scope: Rubber-banding, aggression.

- [ ] **3.4 Race HUD**
  - Goal: Position, lap, split delta, next gate marker, and the assist stack indicator.
  - Context: Reuse the theme from 2.5. The assist indicator stays in every job HUD from here on.
  - Acceptance: Next gate marker stays on screen or at the edge pointing to it. Split delta colors red or green against the best lap.
  - Out of scope: Minimap.

- [ ] **3.5 Act 1 framing**
  - Goal: Present the race as the home video game: a crude in-game bezel, a fake leaderboard with the player's handle, a one-line scout message after a top-three finish.
  - Context: The Last Starfighter beat. Text and a border only.
  - Acceptance: Bezel shows only in jobs tagged `act1`. Scout message fires once, on the first top-three, and sets a flag Epic 5 reads.
  - Out of scope: Cutscenes, voice.

## Epic 4: Hazard jobs

Done when the three drone-work jobs exist: demolition run, search and rescue, inspection. Each puts a crew member in the field and uses a camera view as a tool, never as a score.

- [ ] **4.1 Scripted hazard scene**
  - Goal: A `HazardScene` base: a scene with `AnimationPlayer` timelines for events (a collapse, a storm front, a crane swing) that start on Countdown, plus `Debris` bodies that can strike a `HazardZone`.
  - Context: Extends the job framework from 2.1. Events do not restart on retry mid-job; retry reloads.
  - Acceptance: Events fire at their timeline times. A debris body entering a hazard zone emits `debris_in_zone`. Crew props are no-collision.
  - Out of scope: Runtime destruction physics.

- [ ] **4.2 Demolition run**
  - Goal: A building that collapses on a timeline with pre-authored fractured pieces. The job: enter through a window, fly the interior, exit before the roof comes down. Bea stands at the base inside a hazard zone. Default camera: FPV.
  - Context: The signature job. Requires the Act 3 preset (collision guard off) or the drone refuses the window. Objectives: `ReachPoint` chain, `AvoidContact`, `FinishUnderTime`.
  - Acceptance: Completable with Act 3 assists. Contact with debris is a strike on Bea. Exiting after the roof timeline fails the job. Grade A requires zero contact.
  - Out of scope: Dust, sound.

- [ ] **4.3 Search and rescue**
  - Goal: Ozzie is somewhere in a fog-covered area with a beacon that pings louder as you close. Find him and hold over him for 3 s before the timer runs out. Wind sim is on (Act 4 preset). Default camera: chase.
  - Context: The beacon is audio and a HUD arc, not a marker. Ozzie's position is seeded. Timer expiry is a strike on Ozzie.
  - Acceptance: Beacon strength is a function of distance. Holding over Ozzie completes. Timer expiry strikes and fails. Reproducible with a seed.
  - Out of scope: Multiple targets.

- [ ] **4.4 Inspection and HoldStation**
  - Goal: A `HoldStation` objective: stay inside a sphere for N seconds, timer resets on exit. An inspection job: three holds around a tower in order, no contact, Marlo on a platform in a hazard zone. Default camera: orbit.
  - Context: `HoldStation` is reused by the fleet inspection (6.3) and the boss override (8.5), so keep it generic: center, radius, hold time, reset grace.
  - Acceptance: A scripted hold completes in exactly N seconds. Leaving for more than the grace period resets. The three-hold job completes and grades.
  - Out of scope: Camera-based coverage scoring.

- [ ] **4.5 Weather**
  - Goal: Fog density and wind gusts as per-job data, read by the rescue job and available to any job. Visual fog only; wind feeds the sim from 1.7.
  - Context: Keep rendering simple: Godot volumetric fog or a fog shader, one parameter.
  - Acceptance: Fog density and gust amplitude load from the Job resource. A job with no weather block runs clear and still.
  - Out of scope: Rain, night.

## Epic 5: Progression, teams, and recruitment gates

Done when the player moves from Act 1 to Act 4 by being recruited, each promotion swaps the assist preset, and the job board shows only what the current team offers.

- [ ] **5.1 Teams and factions**
  - Goal: A `Team` resource (name, faction, job types, reputation needed, assist preset granted) and six teams across three factions in `data/teams/`.
  - Context: Reputation per faction from 2.4.
  - Acceptance: Data loads and validates. Each team references only job types that exist.
  - Out of scope: Rival teams.

- [ ] **5.2 Recruitment**
  - Goal: When faction reputation crosses a team's threshold, an offer appears. Accepting sets the current team and applies its preset.
  - Context: Reads the scout flag from 3.5 for the first offer. Offers are one-shot.
  - Acceptance: Top three in the Act 1 race produces the first offer. Accepting switches Act 1 to Act 2 and the HUD indicator changes. Declining and re-crossing does not re-offer.
  - Out of scope: Being fired, contracts.

- [ ] **5.3 Job board**
  - Goal: A hub screen listing the current team's jobs with client, pay, required preset, and a Fly button.
  - Context: Replaces the debug scene as main scene. Locked jobs show which team unlocks them.
  - Acceptance: Only the current team's jobs are flyable. Completing a job returns here. Wallet and reputation show in the header. The crew roster from 7.1 shows with status; dead characters are greyed with their memorial line.
  - Out of scope: Map, travel.

- [ ] **5.4 Save game**
  - Goal: One save file holding wallet, reputation, current team, completed jobs, and the expert toggle.
  - Context: Extends the JSON from 2.4. Saves on job complete and team change.
  - Acceptance: Quit and relaunch restores the job board exactly. A corrupt file falls back to a new game with a warning, not a crash.
  - Out of scope: Multiple slots, cloud.

- [ ] **5.5 Upgrades**
  - Goal: A shop that spends wallet on drone stats: max thrust, battery capacity, drag.
  - Context: Upgrades change exported variables on the Drone scene. Never add or remove assists.
  - Acceptance: Buying max thrust raises climb rate in the debug scene. Prices and effects are data. Cannot buy with insufficient funds.
  - Out of scope: Cosmetics.

## Epic 6: Fleet command layer

Do not start until Epics 3 and 4 have been playtested and the fleet-genre question in VISION.md is answered.

- [ ] **6.1 Autopilot intent source**
  - Goal: An `Intent` source that flies a drone to a waypoint, reusing the AI racer logic from 3.3.
  - Context: Each fleet drone is the same Drone scene under autopilot.
  - Acceptance: A drone reaches five waypoints within 2 m each and holds at the last.
  - Out of scope: Formation flying.

- [ ] **6.2 Command view**
  - Goal: A top-down camera with click-to-select on drones and click-to-set waypoints, plus a key to drop into any drone's first-person view.
  - Context: The Act 5 preset turns single-drone view off; this replaces it.
  - Acceptance: Selecting a drone and clicking the ground queues a waypoint. Dropping in hands it to manual input; leaving resumes autopilot.
  - Out of scope: Drag-select, groups.

- [ ] **6.3 Fleet inspection**
  - Goal: Three structures must each have an inspection hold running at the same time, so three drones must be on station at once.
  - Context: Reuses the `HoldStation` objective from 4.4.
  - Acceptance: Only completable by assigning each structure to a different drone. Grading is per structure, combined as in 2.2.
  - Out of scope: Handoffs between human pilots.

- [ ] **6.4 Fleet race**
  - Goal: A team relay where each lap must be flown by a different drone and the handoff is a gate.
  - Context: Reuses the course from 3.1.
  - Acceptance: A lap flown by the wrong drone is invalid. Handoff timing shows on the HUD.
  - Out of scope: Opponent fleets.

## Epic 7: Characters and consequence

Done when the player picks a pilot, the crew talks through every job, crew members can be hurt or killed on jobs that declare the risk, and the game changes when they are. Read `docs/CHARACTERS.md` before every story here.

- [ ] **7.1 Character roster**
  - Goal: A `Character` resource (id, name, role, portrait, color set, line file, death consequence tag) and the six cast members from CHARACTERS.md in `data/characters/`. A `Roster` autoload tracks status: active, injured (with jobs remaining), dead.
  - Context: Status lives in the save file from 2.4; extend it. Placeholder portraits are colored shapes drawn in code, readable at 64 px.
  - Acceptance: All six load and validate. `Roster.injure(id)` sets injured for 2 jobs; a second `injure` while injured sets dead; `Roster.kill(id)` sets dead; `rin` can never be injured or killed. Status survives save and load. No revive method exists.
  - Out of scope: Final art, voice.

- [ ] **7.2 Pilot select**
  - Goal: A screen to choose the pilot avatar before the first job, defaulting to Pip. The chosen portrait shows in every HUD.
  - Context: Avatars are characters tagged `pilot`. Each has one small stat tweak (e.g. +5 percent battery) applied as an upgrade, never a flight model change.
  - Acceptance: Choice persists in the save. HUD from 3.4 shows the portrait. Changing pilot changes the tweaked stat and nothing else.
  - Out of scope: Unlockable pilots.

- [ ] **7.3 Crew lines**
  - Goal: A `Bark` system: characters speak in briefing, on job events (gate passed, strike warning, strike, complete, fail), and on results. Lines are data in `data/dialogue/<id>.json`, keyed by event, with variants by status.
  - Context: Hooks into `JobRunner` signals from 2.1 and the results screen from 2.5. A portrait and a text box; no audio.
  - Acceptance: Each cast member has at least three lines per event. An injured character uses the injured variant. A dead character never speaks. A line does not repeat within one job unless it is the only one.
  - Out of scope: Voice, branching dialogue.

- [ ] **7.4 Hazard zones and strikes**
  - Goal: Jobs declare `crew_in_field` and place a `HazardZone` per character. A strike fires on drone contact in the zone above a speed threshold, debris landing in the zone, or a rescue timer expiring. The HUD flashes the character's portrait 1 s before a strike can land.
  - Context: Extends `Job` from 2.1. The warning is mandatory: no strike without a prior warning frame.
  - Acceptance: Entering a zone at 10 m/s strikes; at 1 m/s it does not. The warning fires at least 1 s before any strike in a scripted test. A job with no `crew_in_field` can never strike. The results screen lists strikes per character.
  - Out of scope: Crew moving during a job.

- [ ] **7.5 Injury, death, and the launch gate**
  - Goal: Strikes call `Roster.injure`; a strike on a job tagged `lethal` calls `Roster.kill`. Launching a job whose `crew_in_field` includes an injured character shows a confirmation dialog naming the risk.
  - Context: Builds on 7.1 and 7.4. The results screen shows injury and death with the character's line.
  - Acceptance: One strike injures. A second job with a strike on the same injured character kills. Declining the launch dialog returns to the job board. A dead character is removed from `crew_in_field` of every later job and their zone does not spawn.
  - Out of scope: Rookie mode (open question).

- [ ] **7.6 Story consequences**
  - Goal: Apply the consequence table from CHARACTERS.md: Marlo's death removes gate callouts and the split-delta HUD; Dot's closes the shop for three jobs and raises prices 25 percent; Bea's locks the salvage faction; Ozzie's locks city services. The job board shows a memorial line per dead character.
  - Context: Consequences are data on the `Character` resource read by the systems they touch (HUD, shop, team offers). Add one job that requires a specific living character.
  - Acceptance: A test kills each character and checks its consequence is in effect. The locked faction's jobs do not appear on the board. The memorial line is present.
  - Out of scope: Replacement recruits.

- [ ] **7.7 Crew in the fleet**
  - Goal: In Epic 6, living crew members pilot the fleet drones under autopilot and bark on events. A dead crew member is one fewer drone.
  - Context: Do after 6.2. Resolves the fleet open question in CHARACTERS.md.
  - Acceptance: Fleet size equals living crew tagged `can_fly`. Each fleet drone shows its pilot's portrait in the command view.
  - Out of scope: Crew dying during fleet jobs.

## Epic 8: The Lattice

Done when the boss job exists, is beatable by disabling the core, is lethal for crew in the field, and vanishes entirely when `enabled` is false. Read `docs/BOSS.md` before every story here. Requires Epics 6 and 7.

- [ ] **8.1 Boss resource and kill switch**
  - Goal: A `Boss` resource at `data/boss/lattice.tres` with `enabled`, `required_characters` (marlo), `min_fleet` (2), phase timings, and the chorus line file. A `BossGate` check the job board calls.
  - Context: This is the feature flag. Everything else in this epic checks it.
  - Acceptance: With `enabled` false, the job board has no Lattice entry and no `scenes/boss/` scene is ever instanced (test asserts on a resource load spy). With it true but requirements unmet, the board shows the job as unreachable with the reason. With all met, it is flyable.
  - Out of scope: The fight.

- [ ] **8.2 The shell**
  - Goal: A procedurally placed sphere of captured drone units with one assembly trench seam, in `scenes/boss/lattice.tscn`. Units are the Drone scene's mesh, static, no physics per unit.
  - Context: Instancing thousands of meshes needs MultiMesh. Keep it under a frame budget in the headless test by counting instances, not rendering.
  - Acceptance: Unit count and trench width are data. The trench is a continuous navigable path from outside to the core shutter (a test walks it with a sphere cast). Units tagged as crew-owned carry the crew member's color.
  - Out of scope: Textures, lighting.

- [ ] **8.3 Phase 1: reclaim**
  - Goal: Fleet drones under autopilot tag shell units with override pucks; a tagged unit detaches and joins the fleet. Shell defenders disable fleet drones on contact; a disabled drone is recaptured into the shell. A gap opens when N adjacent units are reclaimed.
  - Context: Reuses command view (6.2) and autopilot (6.1). Defender behavior is the AI racer with a target instead of a spline.
  - Acceptance: Reclaiming N adjacent units opens the trench entrance and emits `phase_complete`. Losing all fleet drones fails the job. Reproducible with a seed.
  - Out of scope: Player flying in phase 1.

- [ ] **8.4 Phase 2: the trench**
  - Goal: The player flies the trench with the Act 5 preset while the shell contracts on a timer. Marlo calls turns from `data/dialogue/marlo.json` keyed to trench waypoints. Contact with the shell is a strike on the calling crew member.
  - Context: Reuses gates (3.1) as invisible waypoints and the strike system (7.4). Job is tagged `lethal`.
  - Acceptance: Reaching the shutter emits `phase_complete`. The shell closes the entrance after the configured time and fails the job. A shell contact strikes Marlo. Marlo's death mid-run removes callouts for the rest of the run.
  - Out of scope: Branching trench routes.

- [ ] **8.5 Phase 3: override**
  - Goal: Hold station inside a 1 m sphere at the override port for the configured hold time while the Lattice shakes the trench and gusts wind through it. Leaving the sphere resets the hold.
  - Context: Reuses `HoldStation` from 4.4 and the wind sim from 1.7. Win condition is `hold_complete`, never damage.
  - Acceptance: A scripted perfect hold completes in exactly the hold time. Leaving the sphere for more than 0.5 s resets. Completion emits `boss_disabled` and triggers the power-down sequence.
  - Out of scope: Multiple ports.

- [ ] **8.6 Power-down and epilogue**
  - Goal: On `boss_disabled`, the shell loosens section by section on a timeline, captured units fall free, crew-owned units return to the roster as fleet drones, and the results screen shows a final crew lines pass with living and dead accounted for.
  - Context: Reuses the results screen (2.5) and crew lines (7.3). The chorus speaks once more, then stops.
  - Acceptance: Every living crew member's drone is back in the fleet after the sequence. Dead crew members are named on the results screen and nothing of theirs returns. The save records `lattice_disabled: true`.
  - Out of scope: New game plus.

- [ ] **8.7 Chorus lines**
  - Goal: The Lattice's lines in `data/dialogue/lattice.json`: plural, flat, never first person singular, triggered on phase start, on reclaiming a crew-owned unit, on a strike, and on shutdown. Portrait is a grid of dots that thins as the fight goes on.
  - Context: Uses the bark system from 7.3 with a non-character speaker.
  - Acceptance: Every line passes a test that rejects "I", "me", or "my". The portrait density tracks remaining shell units.
  - Out of scope: Voice.
