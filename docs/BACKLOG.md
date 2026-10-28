# Drone Sports: Backlog

Stories for `/next-story`. Work them top to bottom. Epics 0 to 3 are sequential, with Epic 9 (visual baseline) done between 2 and 3; Epic 10 (navigation) follows the Epic 3 playtest, except 10.5, which waits for 4.1; 4, 5, and 7 can run in parallel after 10.4 (do 7.1 to 7.3 before 5.3, since the job board shows the roster); 6 waits for playtesting; 8 waits for 6 and 7; 12 (the city) is scene content only and can run alongside any of them.

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

- [x] **0.4 Controls overlay**
  - Goal: Players can find the keyboard controls: a controls panel that opens with the sandbox, and a one-line key hint during every job briefing.
  - Context: Playtest feedback: the keys were only written in a code comment. The panel and hint read the InputMap, so a rebound key shows as bound. `toggle_help` (/ or ?) shows and hides the panel anywhere; any flying key closes it.
  - Acceptance: Every project input action is listed with a key. The sandbox opens with the panel up; W hides it; ? brings it back and hides it again. Each of the five jobs shows the hint while in its briefing and hides it on launch, with the panel closed.
  - Out of scope: Gamepad glyphs, rebinding, a settings menu.

- [x] **0.5 Leaving and starting jobs**
  - Goal: Players can tell how to start a job from the sandbox and how to get back out of one.
  - Context: Playtest question. The sandbox is now titled "Free flight" with the job keys in its subtitle; the controls panel groups "In a job" (Enter launch, Esc leave) and "Start a job". Esc in a job goes to the runner's `back_scene`, the sandbox until 5.3 retargets it to the job board.
  - Acceptance: Esc in a briefing leaves at once. Esc in countdown or flight pauses and asks "Leave job?" with "Keep flying" focused; keeping resumes, leaving fails the job (reason "left", no results screen) and goes back. The sandbox HUD reads "Free flight" and "J K L H U start a job", and the job hint line includes Esc.
  - Out of scope: The job board (5.3), a pause menu.

## Epic 1: One flight model with a toggleable assist stack

Done when a quadcopter flies with real physics in the debug scene and each assist can be switched on or off at runtime without changing the physics code.

- [x] **1.1 Quadcopter rigid body**
  - Goal: `scenes/drone/drone.tscn` whose motion comes from four thrust values applied to a RigidBody3D.
  - Context: The only flight model in the game. Every assist sits in front of it, never inside it. Script at `scripts/drone/drone.gd`.
  - Acceptance: With all thrust at hover value the drone holds within 0.1 m of its start height for 10 s of physics ticks. Unequal thrust produces pitch, roll, and yaw in the expected directions. Mass, drag, and max thrust are `@export` variables. A test steps physics and checks hover and each rotation axis.
  - Out of scope: Input, assists, wind, battery.

- [x] **1.2 Raw stick input**
  - Goal: Gamepad and keyboard input mapped to throttle, pitch, roll, yaw, with a mixer that turns them into four motor thrusts.
  - Context: Builds on 1.1. Input fills an `Intent` resource (`scripts/drone/intent.gd`) so assists can rewrite it before the mixer. Input actions are already defined in `project.godot`.
  - Acceptance: Full throttle climbs, zero throttle falls, sticks map to the correct rotations. Mixer is a pure function and unit tested with known inputs.
  - Out of scope: Assists, camera.

- [x] **1.3 Assist pipeline**
  - Goal: An ordered list of `Assist` nodes, each able to read drone state and rewrite `Intent` before the mixer, with an `enabled` flag on each.
  - Context: The progression system's hook. `scripts/drone/assist.gd` base class; `AssistStack` resource (`scripts/drone/assist_stack.gd`) lists which assists are on.
  - Acceptance: Pipeline runs assists in order every physics frame. A disabled assist is skipped. Debug readout shows the stack. Test: a stub assist that zeroes pitch is honored when on, ignored when off.
  - Out of scope: Any real assist.

- [x] **1.4 Collision guard**
  - Goal: An assist that stops the drone before it hits something.
  - Context: First assist, the one players lose first. Uses raycasts or a shape cast ahead of the velocity vector.
  - Acceptance: Flying at a wall at 10 m/s stops within 1 m of it with no contact. Does not alter intent when nothing is ahead. Can be disabled live.
  - Out of scope: Pathing around obstacles.

- [x] **1.5 Altitude hold and auto-level**
  - Goal: Two assists: one holds current height when throttle is centered, one levels the drone when pitch and roll sticks are released.
  - Context: Together these make the drone feel like an arcade flyer. Separately toggleable.
  - Acceptance: With both on, releasing all sticks returns the drone to level flight at constant height within 1 s. With auto-level off, bank angle persists. With altitude hold off, centered throttle sinks.
  - Out of scope: Terrain following.

- [x] **1.6 Camera rig**
  - Goal: A `CameraRig` with four views the player cycles with the `cycle_camera` action (C): chase (behind and above, smoothed), FPV (on the nose, no smoothing), orbit (mouse or right stick swings around the drone), top-down (fixed height, follows). Each job can set a default view.
  - Context: The camera is a tool for flying, never a mechanic (CLAUDE.md rule 8). Chase and orbit must not clip through geometry: pull in on a shape cast.
  - Acceptance: Cycling order is chase, FPV, orbit, top-down, chase. FPV forward equals drone forward every frame. Chase camera never ends a frame inside a collider in a scripted wall-hug test. Job default view is honored on Briefing.
  - Out of scope: Replays, free-fly camera outside debug.

- [x] **1.6a Speed governor**
  - Goal: An assist that caps horizontal speed at a configured value and softens throttle response near the cap.
  - Context: Fourth assist in the act table. Rewrites `Intent` only; never touches the mixer.
  - Acceptance: With it on, full stick holds at the cap within 5 percent. With it off, the same input exceeds the cap. Can be disabled live.
  - Out of scope: Per-job caps.

- [x] **1.7 Battery and wind**
  - Goal: An environment assist that, when off, applies a wind vector and drains a battery; when on, both are disabled.
  - Context: Last assist to come off. Wind is a per-scene resource with a base vector and gust amplitude.
  - Acceptance: With the assist off, the drone drifts in wind unless corrected and the battery reaches zero after the configured flight time, after which thrust fades over 3 s. With it on, neither happens.
  - Out of scope: Weather visuals.

- [x] **1.8 Assist presets by act**
  - Goal: Five `AssistStack` resources in `data/assists/` matching the table in CLAUDE.md (collision guard, altitude hold, auto-level, speed governor, battery and wind, single-drone view), plus a settings toggle that overrides to all-off.
  - Context: Closes the epic. Epic 5 swaps these; for now the `cycle_preset` action (F2) cycles them in the debug scene.
  - Acceptance: F2 cycles Act 1 to Act 5 presets and the readout shows the change. An "Expert: all assists off" setting overrides the preset. Test loads all five resources and checks each matches the table.
  - Out of scope: Saving settings.

- [x] **1.9 Keyboard feel**
  - Goal: Keyboard flying that is controllable: held keys ramp the stick instead of snapping to full, sticks get an expo curve, and once altitude hold is off the keyboard throttle stays where the pilot leaves it.
  - Context: Added after the first hand playtest of Epic 1. All changes live in `PilotInput`; the flight model, mixer, and assists are untouched (CLAUDE.md rule 1).
  - Acceptance: A held key reaches full stick in 0.15 s and returns to center in 0.15 s on release. Gamepad axes pass through with no ramp. Pitch, roll, and yaw use an expo curve that keeps 0 and full deflection. With altitude hold off, W/S nudge a throttle level that holds on release and starts at hover; with altitude hold on, throttle springs back to center as before. Moving the gamepad throttle takes over from the latched level.
  - Out of scope: Rebinding, per-player settings.

- [x] **1.10 Faster rotation**
  - Goal: Full stick rotates fast enough to flip without falling out of the sky: double the mixer's stick authority.
  - Context: Playtest of 1.9 in Act 3: a flip at hover throttle took 1.5 s and lost 8 m. Tuning a mixer constant inside the one flight model; assist attitude gains scale with it so assisted flight feels the same.
  - Acceptance: With no assists, a full-stick flip from hover completes in at most 0.8 s and loses less than 3 m (was 1.5 s and 8 m). All earlier flight and assist tests still pass unchanged.
  - Out of scope: Per-pilot rates, rate curves.

- [x] **1.11 Reset in the debug scene**
  - Goal: The `reset_drone` action (R, or Start on a gamepad) puts the drone back at its spawn point, at rest, with a full battery.
  - Context: Playtest request. `Drone.reset()` also clears held state in assists (altitude hold target) and the intent source (latched throttle).
  - Acceptance: After a flight that leaves the drone moved, tilted, moving, and low on battery, pressing R restores the spawn transform, zero velocity, and a full battery, and the drone then hovers in place under the Act 1 preset.
  - Out of scope: Checkpoints, resetting jobs.

- [x] **1.12 Brake and heading hold**
  - Goal: A new-pilot assist so keyboard flying is controllable: pitch and roll sticks ask for a ground speed, released sticks stop the drift, and released yaw stops the turn.
  - Context: Playtest feedback (keyboard): the drone drifts after the keys are released and turns overshoot. A new `brake` assist runs first in the pipeline and hands auto-level the tilt to hold; on in Acts 1 and 2, off with auto-level in Act 3. The flight model and mixer are untouched. The CLAUDE.md assist table needs a row for it (the file is read-only).
  - Acceptance: Coasting at 10 m/s with sticks released, the drone is below 0.5 m/s within 3 s (without the brake it is still above 3 m/s). Full forward stick holds the brake's max speed (8 m/s) within 10%. Full yaw holds its max turn rate within 10%, and 0.5 s after release the turn is below 5°/s with under 30° of overshoot. The act presets have it on in Acts 1 and 2 only.
  - Out of scope: Camera-relative sticks, rebinding.

- [x] **1.13 Crash recovery**
  - Goal: A drone that crashes into a state it cannot fly out of is put back upright, at rest, where it was last flying level, so a hit never ends a run.
  - Context: Playtest feedback: "really easy to get stuck on an obstacle". Without collision guard (Act 2 on), a full-speed hit pitches the drone 90 degrees so its own thrust pins it to the wall at zero speed; a drone turned over on the ground can never right itself. Friction and bounce tuning did not fix both (zero friction let it tunnel through the ground). A `CrashRecovery` node in the drone scene watches for tilt over 60 degrees with almost no motion for 1.5 s and calls the new `Drone.recover`, which moves the drone like `reset` but keeps the battery. The safe point is the last level position at least 1 s old, lifted 0.5 m. Frozen drones are left alone. AI racers get it too. The flight HUD shows RECOVERED for 2 s. Grading is unchanged: the contact still counts for `AvoidContact`.
  - Acceptance: Pinned to a wall in Act 2, the drone recovers exactly once, stands upright, keeps its battery, and then flies more than 4 m away in 2 s. Turned over on the ground, it recovers upright above the ground. Cruising and an Act 5 full-stick flip never trigger it. A frozen drone is never recovered.
  - Out of scope: A manual recover key in jobs, turtle mode.

## Epic 2: Job framework, grading, and payout

Done when any scene can declare itself a job, run start to finish, produce a grade, and pay out, with no job-specific code in the framework.

- [x] **2.1 Job resource and lifecycle**
  - Goal: A `Job` resource (id, title, client, required assist stack, time limit, pay) and a `JobRunner` node moving through Briefing, Countdown, Live, Complete, Failed.
  - Context: Every job type in Epics 3, 4, 6 plugs into this runner. `scripts/jobs/job.gd`, `scripts/jobs/job_runner.gd`.
  - Acceptance: Runner emits `state_changed` on each transition. Time limit ends the job as Failed. A test job with no objectives completes when `complete()` is called. Required assist stack is applied to the drone on Briefing.
  - Out of scope: UI beyond a text state label.

- [x] **2.2 Objectives and graders**
  - Goal: An `Objective` base class with `score() -> float` in 0 to 1 and a `weight`, and a `Grader` that combines objectives into a grade A to F.
  - Context: Jobs add objectives as child nodes. Grade thresholds are data (A at 0.9, B at 0.75, C at 0.6, D at 0.4).
  - Acceptance: Two objectives at weights 2 and 1 scoring 1.0 and 0.0 grade to 0.67, a C. Unit tested.
  - Out of scope: Any concrete objective.

- [x] **2.3 Common objectives**
  - Goal: Three reusable objectives: `ReachPoint`, `AvoidContact`, `FinishUnderTime`.
  - Context: Enough for a race and a delivery. Hazard objectives come in Epic 4.
  - Acceptance: Each has a test proving a passing and failing run. `AvoidContact` deducts per collision and floors at 0.
  - Out of scope: Combat objectives.

- [x] **2.4 Payout and reputation**
  - Goal: `Wallet` and `Reputation` autoloads. Completing a job pays `pay * grade multiplier` and adds reputation with the client faction.
  - Context: Reputation gates Epic 5. Both are plain numbers saved to `user://save.json`.
  - Acceptance: An A pays 100 percent, a C pays 60 percent, an F pays 0 and costs 5 reputation. Values persist across a save and load.
  - Out of scope: Spending, upgrades.

- [x] **2.5 Results screen**
  - Goal: A screen after each job listing every objective, its score, the grade, pay, and reputation change, with Retry and Continue.
  - Context: First real UI. One scene, one theme file in `scenes/ui/`.
  - Acceptance: Shows within 1 s of job end. Retry reloads the same job. Continue returns to the debug scene.
  - Out of scope: Leaderboards, replays.

## Epic 9: Visual baseline (golden hour)

Done when every flying scene shares one golden-hour desert look: low warm sun, haze, dunes and ridges, a readable drone, speed cues, and a thin-line flight HUD. Inspired by a sunset desert flight reference; no combat elements. Done before Epic 3 so the race is built and playtested in the new look. Visuals only: nothing here touches the flight model, assists, or grading.

- [x] **9.1 Golden-hour sky and light**
  - Goal: One shared `scenes/world/golden_hour.tscn` (WorldEnvironment + sun) used by the debug scene and every job scene.
  - Context: Settings live in `data/world/golden_hour.tres` (an Environment). Physical or procedural sky with a low sun, filmic tonemapping, glow, and distance fog tinted toward the sun. Effects that GL Compatibility lacks degrade silently on web.
  - Acceptance: The debug scene and the sample job both instance the world scene and contain no other WorldEnvironment. The sun sits under 20 degrees above the horizon and casts shadows. Fog and glow are on. Both scenes load headless with no errors.
  - Out of scope: Time of day, weather.

- [x] **9.2 Desert terrain**
  - Goal: Sand ground with dune detail and a ring of rocky ridges fading into the haze.
  - Context: Generated from a seeded noise at load. The flight area stays flat so jobs and tests keep their geometry; ridges start outside it and have collision.
  - Acceptance: Inside a 150 m radius the ground is flat at y = 0. Ridge heights are identical for the same seed. Flying into a ridge is a contact. Both scenes load headless with no errors.
  - Out of scope: Streaming, editable terrain.

- [x] **9.3 Drone look**
  - Goal: A dark carbon frame with arms, motors, and props that spin with motor thrust; motor glow that brightens with thrust; white front and red rear lights.
  - Context: A visual node reads `Drone.motor_thrusts`. Mesh changes only; collision shape and mass are untouched.
  - Acceptance: Prop spin rate and glow rise with motor thrust and are zero at zero thrust. The drone's collision shape and mass are unchanged. All flight tests still pass unchanged.
  - Out of scope: Damage visuals, liveries.

- [x] **9.4 Speed cues**
  - Goal: The chase and FPV field of view widens with speed; sand dust kicks up under the drone near the ground.
  - Context: Camera stays a tool (CLAUDE.md rule 8). CPU particles so the web build matches. The flying scenes also bring the chase camera in to 1.5 m so the drone reads on screen; the rig's defaults are unchanged.
  - Acceptance: FOV at 20 m/s is wider than at rest and returns when the drone stops. Dust emits only within 3 m of the ground with thrust on.
  - Out of scope: Motion blur, screen shake.

- [x] **9.5 Flight HUD**
  - Goal: A thin-line HUD: compass heading tape at top, speed and altitude readouts at the sides, a job and objectives panel at top left, assist stack indicator, battery.
  - Context: Reuse the theme from 2.5. Jobs feed the panel from `JobRunner`; the debug scene shows the preset instead. Story 3.4 builds the race HUD on top of this.
  - Acceptance: Heading tape reads the drone's yaw (W at 270). Speed and altitude match the drone within rounding. The objectives panel lists the runner's objectives and state. The assist indicator lists the active assists.
  - Out of scope: Minimap, race position.

## Epic 3: Race job

Done when a player can fly a gated race against AI drones with Act 1 assists, get graded, and get paid. This is the playable slice; stop and playtest here.

- [x] **3.1 Gate and course**
  - Goal: A `Gate` node that detects a pass-through in the correct direction, and a `Course` that orders gates and tracks laps.
  - Context: Builds on `ReachPoint` from 2.3. The signal also carries the racer, lap number, and validity, since one course tracks every racer: `lap_completed(time, racer, lap, valid)`. Invalid laps do not count toward the race.
  - Acceptance: Passing a gate backwards does not count. Skipping a gate invalidates the lap. Course emits `lap_completed(time)`. A test course with 8 gates and 2 laps exists in `data/courses/`.
  - Out of scope: Course editor.

- [x] **3.2 Race objectives**
  - Goal: `FinishPosition`, `CleanLap`, `BestSplit` objectives and a `RaceJob` scene wiring them to the course.
  - Context: Finish position weighted highest. Weights live in the Job resource.
  - Acceptance: First-place clean run grades A. Last place with contact grades no higher than D.
  - Out of scope: Multiplayer.

- [x] **3.3 AI racers**
  - Goal: Three opponent drones that fly the course on a spline with speed noise and a small chance to clip a gate.
  - Context: Same `Drone` scene with a scripted `Intent` source instead of input, so physics match the player.
  - Acceptance: Opponents finish within 10 percent of each other on the test course. They never leave course bounds. Lap times reproducible with a seed.
  - Out of scope: Rubber-banding, aggression.

- [x] **3.4 Race HUD**
  - Goal: Position, lap, split delta, next gate marker, and the assist stack indicator.
  - Context: Reuse the theme from 2.5. The assist indicator stays in every job HUD from here on.
  - Acceptance: Next gate marker stays on screen or at the edge pointing to it. Split delta colors red or green against the best lap.
  - Out of scope: Minimap.

- [x] **3.5 Act 1 framing**
  - Goal: Present the race as the home video game: a crude in-game bezel, a fake leaderboard with the player's handle, a one-line scout message after a top-three finish.
  - Context: The Last Starfighter beat. Text and a border only.
  - Acceptance: Bezel shows only in jobs tagged `act1`. Scout message fires once, on the first top-three, and sets a flag Epic 5 reads.
  - Out of scope: Cutscenes, voice.

## Epic 10: Navigation (GPS and maps)

Done when the player always knows where they are and where the job wants them: a GPS grid reference, a radar minimap, a full map screen, and a route line to the next objective. Navigation reads the world and draws UI. It never moves a drone and is not an assist (CLAUDE.md rules 1 and 2), and nothing is graded on it (rule 8). Do it after the Epic 3 playtest and before Epic 4, since delivery and hazard jobs lean on it more than the race does.

- [x] **10.1 Map data and GPS readout**
  - Goal: A `MapData` resource per flying scene (area bounds, grid origin, grid cell size, named landmarks), a `MapMarker` node that any scene object can carry (kind, label, icon, visibility), and a GPS readout on the flight HUD: grid reference and signal strength next to the compass.
  - Context: Data over code (rule 4). Jobs declare their own markers by placing `MapMarker` children on gates, drop points, and hazard zones, so the map holds no job-specific code (rule 3). A marker can be hidden from the map, so jobs like 4.3 can keep a target off it. Map data lives in `data/maps/`.
  - Acceptance: The grid reference matches the drone's world position for a known point and changes cell at the cell boundary. Collecting markers returns every visible `MapMarker` in the scene with its kind and position, and none of the hidden ones. The debug scene, sample delivery, and test race each load a `MapData`.
  - Out of scope: Real-world map data, latitude and longitude.

- [x] **10.2 Radar minimap**
  - Goal: A round radar in a HUD corner, heading-up, showing the player, other drones, visible markers, and the next objective, over a terrain image of the area.
  - Context: Drawn in `_draw` from marker positions, not rendered by a second camera, so it is cheap on the web build and is not a camera view (rule 8). The terrain image is baked once from `DesertTerrain.height_at` and cached like the terrain mesh. Markers beyond the radar range clamp to the rim, pointing their way. Matches the thin-line look from 9.5.
  - Acceptance: A marker straight ahead of the drone draws straight up on the radar at its scaled distance, whatever the drone's yaw. A marker beyond range draws on the rim at the correct bearing. In the test race the radar shows the three opponents and lights the next gate.
  - Out of scope: Fog of war, map zoom levels.

- [x] **10.3 Full map screen**
  - Goal: The `toggle_map` action (M) opens a north-up chart of the whole area: terrain, grid, landmarks, markers, the player's track so far, and the job's route.
  - Context: Same marker data and terrain image as 10.2. Opens as an overlay during Live without pausing the job, and from Briefing for route planning. Not the fleet command view: 6.2 has its own top-down camera. The map sits on its own CanvasLayer above the HUD and the Act 1 bezel. The route line arrives with 10.4.
  - Acceptance: M toggles the map in the debug scene, the delivery job, and the race. A world point maps to the chart and back within one pixel. The job timer keeps running while the map is open. The player's track records only while Live.
  - Out of scope: Placing waypoints on the map (6.2), fast travel.

- [x] **10.4 GPS route guidance**
  - Goal: A route from the drone to the job's next objective, drawn as a dotted line on the radar and the map and as a faint ribbon in the world.
  - Context: Jobs supply the route through a `RouteSource` on the scene: a race uses the course path the AI flies (3.3), a delivery routes straight to its next `ReachPoint`, and 6.1 waypoints use it later. How much guidance shows (full, next leg only, none) is a per-job display setting in the Job resource (`Job.guidance`: FULL, NEXT_LEG, NONE), not an assist, so it never touches the assist table. Before the start, a race route shows the start gate and then the whole first lap.
  - Acceptance: In the test race the route runs through the remaining gates in order and updates when a gate is passed. In the delivery job the route ends at the active drop point. A job set to no guidance draws no route anywhere.
  - Out of scope: Pathfinding around obstacles.

- [x] **10.5 GPS jamming**
  - Goal: A `JammingZone` that degrades GPS inside its radius: the signal readout drops, the grid reference drifts, the radar fuzzes, and the route line disappears when the signal is lost.
  - Context: Waits for 4.1, since jamming is hazard-scene data. HUD only: the flight model and assists are untouched, and the drone flies identically with or without signal. Drift is seeded so runs reproduce. Built as `scenes/nav/jammer.tscn` (a `JammingZone` with a mast and a map marker); one sits beside the delivery route and one in the sandbox. Signal falls linearly over `fade` metres in from the edge and recovers the instant the drone leaves. `RouteSource.gps` hides the route without a fix; the radar centres on the drifting fix.
  - Acceptance: Signal strength is a function of distance to the zone edge. At zero signal the route is hidden and the radar shows no markers. Leaving the zone restores everything within a second. Drift is reproducible with a seed.
  - Out of scope: GPS position hold as an assist (it would change the assist table in CLAUDE.md; decide separately), jamming that affects flight.

- [x] **10.6 Target marker**
  - Goal: The next place the job wants the drone is marked on screen: a diamond over it when in view, an arrow at the screen edge pointing toward it when not, with the distance.
  - Context: Playtest feedback: pilots lost track of where the pad and targets were. `TargetMarker` reads the job's `RouteSource`, so it shows only what guidance allows and nothing without a GPS fix. Placed on the delivery, inspection, and demolition jobs; the race already marks its next gate, and now shares the same placement and drawing.
  - Acceptance: On the delivery job the marker sits over the drop pad with the right distance. Facing away, it sits on screen at the edge and points down. It vanishes inside a jammer and returns outside, and shows nothing with guidance off. Every guided job scene has one wired up. Race HUD tests still pass.
  - Out of scope: Markers in the debug sandbox, waypoint lists.

- [x] **10.7 Sandbox boxes on the radar**
  - Goal: The four practice boxes in the debug sandbox show on the radar and map, so the pilot can find them.
  - Context: Playtest request. Each box gets a `MapMarker` (landmark, square); no code changes.
  - Acceptance: In the debug scene the radar shows four square blips, one at each box.
  - Out of scope: Objectives in the sandbox.

## Epic 4: Hazard jobs

Done when the three drone-work jobs exist: demolition run, search and rescue, inspection. Each puts a crew member in the field and uses a camera view as a tool, never as a score.

Order: 4.1, 4.4, 4.5, then 7.1 and 7.4, then 4.2 and 4.3. Demolition and rescue strike crew members, and strikes (with their mandatory warning) come from 7.4.

- [x] **4.1 Scripted hazard scene**
  - Goal: A `HazardScene` base: a scene with `AnimationPlayer` timelines for events (a collapse, a storm front, a crane swing) that start on Countdown, plus `Debris` bodies that can strike a `HazardZone`.
  - Context: Extends the job framework from 2.1. Events do not restart on retry mid-job; retry reloads. `scenes/hazard/hazard_scene.tscn` is the base: method tracks call `fire_event(name)`, and `Debris` with `release_on` set falls when that event fires. `HazardZone` here only reports what enters it; strikes come in 7.4.
  - Acceptance: Events fire at their timeline times. A debris body entering a hazard zone emits `debris_in_zone`. Crew props are no-collision.
  - Out of scope: Runtime destruction physics.

- [x] **4.2 Demolition run**
  - Goal: A building that collapses on a timeline with pre-authored fractured pieces. The job: enter through a window, fly the interior, exit before the roof comes down. Bea stands at the base inside a hazard zone. Default camera: FPV.
  - Context: The signature job. Requires the Act 3 preset (collision guard off) or the drone refuses the window. Objectives: `ReachPoint` chain, `AvoidContact`, `FinishUnderTime`, plus `BeatEvent` (exit before the roof event or fail). "Contact with debris" means knocking debris onto Bea: loose cornice blocks under the entry window fall when the drone touches them, and one landing in her zone is a strike, warned at least 1 s ahead (7.4). H launches it from the debug scene. The job always flies Act 3, so the guard never meets the window. The guard sweeps only the drone's own shape, so it would not reliably refuse a centred approach; a wider sweep made the AI racers brake at gate posts.
  - Acceptance: Completable with Act 3 assists. Contact with debris is a strike on Bea. Exiting after the roof timeline fails the job. Grade A requires zero contact.
  - Out of scope: Dust, sound.

- [x] **4.3 Search and rescue**
  - Goal: Ozzie is somewhere in a fog-covered area with a beacon that pings louder as you close. Find him and hold over him for 3 s before the timer runs out. Wind sim is on (Act 4 preset). Default camera: chase.
  - Context: The beacon is audio and a HUD arc, not a marker. Ozzie's position is seeded. Timer expiry is a strike on Ozzie. `RescueTimer` warns Ozzie's zone for the last 1.5 s, so the expiry strike follows a full warning, then fails the job. The job sets guidance to NONE and places no route or map marker for him. U launches it from the debug scene; weather is `data/weather/whiteout.tres`.
  - Acceptance: Beacon strength is a function of distance. Holding over Ozzie completes. Timer expiry strikes and fails. Reproducible with a seed.
  - Out of scope: Multiple targets.

- [x] **4.4 Inspection and HoldStation**
  - Goal: A `HoldStation` objective: stay inside a sphere for N seconds, timer resets on exit. An inspection job: three holds around a tower in order, no contact, Marlo on a platform in a hazard zone. Default camera: orbit.
  - Context: `HoldStation` is reused by the fleet inspection (6.3) and the boss override (8.5), so keep it generic: center, radius, hold time, reset grace, plus an optional `after` hold so holds run in order. Leaving pauses the hold; staying out past the grace resets it. The job flies with the Act 2 preset; L launches it from the debug scene. Marlo's zone only reports until 7.4 adds strikes.
  - Acceptance: A scripted hold completes in exactly N seconds. Leaving for more than the grace period resets. The three-hold job completes and grades.
  - Out of scope: Camera-based coverage scoring.

- [x] **4.5 Weather**
  - Goal: Fog density and wind gusts as per-job data, read by the rescue job and available to any job. Visual fog only; wind feeds the sim from 1.7.
  - Context: Keep rendering simple: Godot volumetric fog or a fog shader, one parameter. `Job.weather` is a `Weather` resource (fog density plus a `Wind`) in `data/weather/`; `JobRunner` applies it on Briefing to a copy of the scene's Environment, so the shared golden-hour resource is untouched.
  - Acceptance: Fog density and gust amplitude load from the Job resource. A job with no weather block runs clear and still.
  - Out of scope: Rain, night.

## Epic 5: Progression, teams, and recruitment gates

Done when the player moves from Act 1 to Act 4 by being recruited, each promotion swaps the assist preset, and the job board shows only what the current team offers.

- [x] **5.1 Teams and factions**
  - Goal: A `Team` resource (name, faction, job types, reputation needed, assist preset granted) and six teams across three factions in `data/teams/`.
  - Context: Reputation per faction from 2.4. Jobs gained a `job_type` (race, delivery, inspection, demolition, rescue); "exists" means some job in `data/jobs/` has that type, so arena waits for an arena job. Factions are league, city, salvage, two teams each; `data/teams/teams.tres` lists them for exported builds. Skyline Juniors (league, Act 2, needs 0) is the team Coach Rin scouts for, for 5.2.
  - Acceptance: Data loads and validates. Each team references only job types that exist.
  - Out of scope: Rival teams.

- [x] **5.2 Recruitment**
  - Goal: When faction reputation crosses a team's threshold, an offer appears. Accepting sets the current team and applies its preset.
  - Context: Reads the scout flag from 3.5 for the first offer. Offers are one-shot. A `Career` autoload holds the team and the offers (save section "career"). A team with `needs_flag` (Skyline Juniors: scouted) asks on the flag alone, whatever the race grade. Teams only ask for a later act than the pilot's. Offers appear on the results screen as a dialog naming the assists that come off. Jobs fly with their own assists capped by the career preset (`JobRunner.assists_for`); the HUD's assists header shows act and team.
  - Acceptance: Top three in the Act 1 race produces the first offer. Accepting switches Act 1 to Act 2 and the HUD indicator changes. Declining and re-crossing does not re-offer.
  - Out of scope: Being fired, contracts.

- [x] **5.3 Job board**
  - Goal: A hub screen listing the current team's jobs with client, pay, required preset, and a Fly button.
  - Context: Replaces the debug scene as main scene. Locked jobs show which team unlocks them. Jobs gained `scene`; `data/jobs/board.tres` lists them. In Act 1 only `act1`-tagged jobs fly; on a team, its job types. The row's preset is the stricter of the job's and the career's. Back out, Esc, and the results screen's Continue all return here; free flight is a button, and Esc in free flight comes back. Offers also ask here.
  - Acceptance: Only the current team's jobs are flyable. Completing a job returns here. Wallet and reputation show in the header. The crew roster from 7.1 shows with status; dead characters are greyed with their memorial line.
  - Out of scope: Map, travel.

- [x] **5.4 Save game**
  - Goal: One save file holding wallet, reputation, current team, completed jobs, and the expert toggle.
  - Context: Extends the JSON from 2.4. Saves on job complete and team change. Completed jobs are counts in the "career" section and show on the board ("done 2×"); the expert toggle is the "settings" section, saved when toggled. A file that will not parse is renamed to `save.json.corrupt` and the board shows a one-time warning. `SaveGame.load_all` re-reads every section, as a launch does.
  - Acceptance: Quit and relaunch restores the job board exactly. A corrupt file falls back to a new game with a warning, not a crash.
  - Out of scope: Multiple slots, cloud.

- [x] **5.5 Upgrades**
  - Goal: A shop that spends wallet on drone stats: max thrust, battery capacity, drag.
  - Context: Upgrades change exported variables on the Drone scene. Never add or remove assists. `Upgrade` resources in `data/upgrades/` (stat, step per level, a price per level); a `Garage` autoload holds levels (save section "upgrades") and applies them to the player's drone in each job's briefing and in free flight, never to AI racers. The shop opens from the job board.
  - Acceptance: Buying max thrust raises climb rate in the debug scene. Prices and effects are data. Cannot buy with insufficient funds.
  - Out of scope: Cosmetics.

## Epic 6: Fleet command layer

Do not start until Epics 3 and 4 have been playtested and the fleet-genre question in VISION.md is answered.

- [x] **6.1 Autopilot intent source**
  - Goal: An `Intent` source that flies a drone to a waypoint, reusing the AI racer logic from 3.3.
  - Context: Each fleet drone is the same Drone scene under autopilot.
  - Acceptance: A drone reaches five waypoints within 2 m each and holds at the last.
  - Out of scope: Formation flying.
  - Note: Started on the user's go-ahead ("finish all epics"), before a recorded playtest of Epics 3 and 4; the fleet question is answered in VISION.md. `Autopilot` flies with its own stack (`data/assists/autopilot.tres`: guard, altitude hold, auto-level, governor; no brake). The racer's steering is now the static `AiPilot.steer`, which both use.

- [x] **6.2 Command view**
  - Goal: A top-down camera with click-to-select on drones and click-to-set waypoints, plus a key to drop into any drone's first-person view.
  - Context: The Act 5 preset turns single-drone view off; this replaces it.
  - Acceptance: Selecting a drone and clicking the ground queues a waypoint. Dropping in hands it to manual input; leaving resumes autopilot.
  - Out of scope: Drag-select, groups.
  - Note: `scenes/fleet/command_view.tscn` (CommandView) takes `drones` and a `camera_rig`. Click selects or queues a waypoint 10 m above the ground hit; Tab cycles; F (`drop_in`) moves its PilotInput onto the drone with the career preset, and F again hands back to `Autopilot.of(drone)`, which re-applies its own stack. Jobs in 6.3 and 6.4 instance it.

- [x] **6.3 Fleet inspection**
  - Goal: Three structures must each have an inspection hold running at the same time, so three drones must be on station at once.
  - Context: Reuses the `HoldStation` objective from 4.4.
  - Acceptance: Only completable by assigning each structure to a different drone. Grading is per structure, combined as in 2.2.
  - Out of scope: Handoffs between human pilots.
  - Note: `scenes/jobs/fleet_inspection.tscn` ("Rooftop relay sweep") in the sandbox city: three relays 5 m over rooftop pads. `FleetHold` extends `HoldStation`; a group counts only while every hold has its own drone inside, and each grades 1.0 at dead centre down to 0.5 at the radius edge. `CommandView.runner` holds the fleet still until Live and keeps each drone on its autopilot stack. No team reaches Act 5, so job type `fleet` went to the top city and salvage teams (City Rescue Air, Deadweight); the board lists the job.

- [x] **6.4 Fleet race**
  - Goal: A team relay where each lap must be flown by a different drone and the handoff is a gate.
  - Context: Reuses the course from 3.1.
  - Acceptance: A lap flown by the wrong drone is invalid. Handoff timing shows on the HUD.
  - Out of scope: Opponent fleets.
  - Note: `scenes/jobs/fleet_race.tscn` ("Team relay", job type `relay`, flown by Halcyon Racing) on the 3.1 loop. `Relay` sets the course's laps to unlimited and owns the legs. A lap by a drone other than the open leg's, one that missed a gate, or one started before the handoff is invalid and the leg stays open. G (`send_lap`) sends the selected drone round on autopilot; `Autopilot.corner_speed` lets it fly through gates without stopping. Graded on legs (minus invalid laps) and mean handoff gap.

## Epic 7: Characters and consequence

Done when the player picks a pilot, the crew talks through every job, crew members can be hurt or killed on jobs that declare the risk, and the game changes when they are. Read `docs/CHARACTERS.md` before every story here.

- [x] **7.1 Character roster**
  - Goal: A `Character` resource (id, name, role, portrait, color set, line file, death consequence tag) and the six cast members from CHARACTERS.md in `data/characters/`. A `Roster` autoload tracks status: active, injured (with jobs remaining), dead.
  - Context: Status lives in the save file from 2.4; extend it. Placeholder portraits are colored shapes drawn in code, readable at 64 px (`CharacterPortrait`). The Roster loads `data/characters/cast.tres`, a list, so exported builds find every character. `Roster.job_done()` counts injured characters back toward active; 7.5 calls it when a job ends. Pip (the player) and Rin both have `can_be_harmed` off.
  - Acceptance: All six load and validate. `Roster.injure(id)` sets injured for 2 jobs; a second `injure` while injured sets dead; `Roster.kill(id)` sets dead; `rin` can never be injured or killed. Status survives save and load. No revive method exists.
  - Out of scope: Final art, voice.

- [x] **7.2 Pilot select**
  - Goal: A screen to choose the pilot avatar before the first job, defaulting to Pip. The chosen portrait shows in every HUD.
  - Context: Avatars are characters tagged `pilot`. Each has one small stat tweak (e.g. +5 percent battery) applied as an upgrade, never a flight model change. The avatars live in their own list, `data/characters/pilots.tres` (Pip first, then Tally, Fen, and Moss), so the crew Roster stays the six from CHARACTERS.md. The tweak is an `Upgrade` on `Character.tweak` that `Garage.apply` adds once per drone after the shop levels, so AI racers never get it: Tally +15 s flight time (5 percent), Fen +0.15 N thrust per motor, Moss -0.015 drag; Pip has none and is the baseline. The choice is `pilot` in the save's `profile` section (`PlayerProfile`). `PilotSelect` is a full-screen layer on the job board that opens on its own until a pilot is chosen, so a new game picks after the intro and before the first job, and reopens from the board's Pilot button. The race HUD shows the portrait beside the position; the flight HUD shows it top right, off in the race scene where the race HUD has that corner. The new pilots have line files but do not speak yet: barks still come from the Roster, so Pip keeps reacting to the finish.
  - Acceptance: Choice persists in the save. HUD from 3.4 shows the portrait. Changing pilot changes the tweaked stat and nothing else.
  - Out of scope: Unlockable pilots.

- [x] **7.3 Crew lines**
  - Goal: A `Bark` system: characters speak in briefing, on job events (gate passed, strike warning, strike, complete, fail), and on results. Lines are data in `data/dialogue/<id>.json`, keyed by event, with variants by status.
  - Context: Hooks into `JobRunner` signals from 2.1 and the results screen from 2.5. A portrait and a text box; no audio. Who speaks is data: crew in the field speak on every event, and `Character.speaks_on` adds voices from afar (Rin briefs and debriefs, Marlo calls gates, Dot grumbles on fails and results, Pip reacts to the finish). Warning and strike lines come from the character in the zone. A `Bark` node and a `BarkBox` sit in every job scene; the closing line lands in `JobResult.bark` for the results screen. A line pool that runs dry goes quiet rather than repeat, and gate callouts are spaced 2.5 s apart.
  - Acceptance: Each cast member has at least three lines per event. An injured character uses the injured variant. A dead character never speaks. A line does not repeat within one job unless it is the only one.
  - Out of scope: Voice, branching dialogue.

- [x] **7.4 Hazard zones and strikes**
  - Goal: Jobs declare `crew_in_field` and place a `HazardZone` per character. A strike fires on drone contact in the zone above a speed threshold, debris landing in the zone, or a rescue timer expiring. The HUD flashes the character's portrait 1 s before a strike can land.
  - Context: Extends `Job` from 2.1. The warning is mandatory: no strike without a prior warning frame. Zones are spheres. Each zone sees threats coming 1.5 s ahead (the drone's line at speed, debris on a ballistic path, or a job calling `threaten()`), and a strike lands only once its warning is at least 1 s old. A threat too sudden to warn for in time does not strike. `JobRunner` arms every zone in its scene on Briefing and counts strikes into `JobResult.strikes`; `CrewWarning` is the HUD. Injury and death are wired in 7.5.
  - Acceptance: Entering a zone at 10 m/s strikes; at 1 m/s it does not. The warning fires at least 1 s before any strike in a scripted test. A job with no `crew_in_field` can never strike. The results screen lists strikes per character.
  - Out of scope: Crew moving during a job.

- [x] **7.5 Injury, death, and the launch gate**
  - Goal: Strikes call `Roster.injure`; a strike on a job tagged `lethal` calls `Roster.kill`. Launching a job whose `crew_in_field` includes an injured character shows a confirmation dialog naming the risk.
  - Context: Builds on 7.1 and 7.4. The results screen shows injury and death with the character's line. Done after 7.3 (the lines) and before 5.3 (the board), so declining goes to `JobRunner.back_scene`, the sandbox for now; 5.3 points it at the job board. Injury shows the character's `hurt` line; death shows their `memorial` line from the same file, since the dead never speak. Strikes only hurt the roster when the runner `pays_out`. The injured character's own job does not count toward their recovery. The dialog's default button is Back out.
  - Acceptance: One strike injures. A second job with a strike on the same injured character kills. Declining the launch dialog returns to the job board. A dead character is removed from `crew_in_field` of every later job and their zone does not spawn.
  - Out of scope: Rookie mode (open question).

- [x] **7.6 Story consequences**
  - Goal: Apply the consequence table from CHARACTERS.md: Marlo's death removes gate callouts and the split-delta HUD; Dot's closes the shop for three jobs and raises prices 25 percent; Bea's locks the salvage faction; Ozzie's locks city services. The job board shows a memorial line per dead character.
  - Context: Consequences are data on the `Character` resource read by the systems they touch (HUD, shop, team offers). Add one job that requires a specific living character. One static query, `Consequences`, answers whether a `death_consequence` tag is in effect (a dead character carries it), so the HUD, shop, career, and board never name a character. `no_spotter`: `RaceHud.split_visible` is off and `Bark` makes no gate callouts. `shop_closed`: for the dead, the roster's `jobs` counts jobs finished since the death (no new save section; the job they died on does not count), the shop stays shut until three have passed (the board's Shop button is disabled and says how many jobs are left; `Garage.can_buy` and `buy` refuse), and `Garage.price` is 25 percent higher from the death on. `salvage_locked` and `city_locked` lock that faction for good: its teams make no offers, pending ones are withdrawn, and its jobs leave the board. A pilot already on a locked faction's team keeps the team and its assists, also flies the home game's jobs so the career cannot dead-end, and may be signed by a team of the same act. `Job.requires_living` names characters a job needs; the new Spotter drill (league race, Marlo on the radio; `scenes/jobs/spotter_drill.tscn` inherits the test race scene) shows "Closed: needs Marlo" once Marlo is dead. Memorial lines stay in the crew rows from 7.5.
  - Acceptance: A test kills each character and checks its consequence is in effect. The locked faction's jobs do not appear on the board. The memorial line is present.
  - Out of scope: Replacement recruits.

- [x] **7.7 Crew in the fleet**
  - Goal: In Epic 6, living crew members pilot the fleet drones under autopilot and bark on events. A dead crew member is one fewer drone.
  - Context: Do after 6.2. Resolves the fleet open question in CHARACTERS.md.
  - Acceptance: Fleet size equals living crew tagged `can_fly`. Each fleet drone shows its pilot's portrait in the command view.
  - Out of scope: Crew dying during fleet jobs.
  - Note: `FleetCrew` (before the command view, relay, and runner in a fleet scene) builds one drone per living `can_fly` crew member at its Marker3D slots, names it after its pilot, and hands the fleet on. Pip, Marlo, Dot, and Ozzie fly, so the full fleet is four and the relay runs four legs. Pilots answer orders with the new `order` event in their line files. The fleet inspection needs three, so it stops being completable after two of the four die; nothing on the board says so yet.

## Epic 8: The Lattice

Done when the boss job exists, is beatable by disabling the core, is lethal for crew in the field, and vanishes entirely when `enabled` is false. Read `docs/BOSS.md` before every story here. Requires Epics 6 and 7.

- [x] **8.1 Boss resource and kill switch**
  - Goal: A `Boss` resource at `data/boss/lattice.tres` with `enabled`, `required_characters` (marlo), `min_fleet` (2), phase timings, and the chorus line file. A `BossGate` check the job board calls.
  - Context: This is the feature flag. Everything else in this epic checks it.
  - Acceptance: With `enabled` false, the job board has no Lattice entry and no `scenes/boss/` scene is ever instanced (test asserts on a resource load spy). With it true but requirements unmet, the board shows the job as unreachable with the reason. With all met, it is flyable.
  - Out of scope: The fight.
  - Note: `Boss` also has `after_job` (default `fleet_race`), so the Lattice follows the fleet final instead of being flyable on a new game; it shows on the board as unreachable until then. `BossGate.open()` is the only way into a boss scene and records each load in `BossGate.loads`, the spy the test reads along with `ResourceLoader.has_cached`. The boss job lives in `data/boss/`, off `board.tres`.

- [x] **8.2 The shell**
  - Goal: A procedurally placed sphere of captured drone units with one assembly trench seam, in `scenes/boss/lattice.tscn`. Units are the Drone scene's mesh, static, no physics per unit.
  - Context: Instancing thousands of meshes needs MultiMesh. Keep it under a frame budget in the headless test by counting instances, not rendering.
  - Acceptance: Unit count and trench width are data. The trench is a continuous navigable path from outside to the core shutter (a test walks it with a sphere cast). Units tagged as crew-owned carry the crew member's color.
  - Out of scope: Textures, lighting.
  - Note: `Lattice` (`scenes/boss/lattice.tscn`) draws three layers of units (about 5,600 for 2,400 in the outer layer) from `DroneLook.still_mesh()`, the drone's body without props. The shell's shape lives on `Boss` (radius 60 m; lid, tunnel, floor; trench width and arc). Contact is analytic (`solid`, `touching`, `sphere_cast`), since units have no physics. The trench is a tunnel inside the shell from a lidded entrance at +x round to a shutter over the core's port. Each `can_fly` crew member has one lost unit in their colour. The headless renderer keeps no instance data, so the test checks `color_of`, the colour each instance is given.

- [x] **8.3 Phase 1: reclaim**
  - Goal: Fleet drones under autopilot tag shell units with override pucks; a tagged unit detaches and joins the fleet. Shell defenders disable fleet drones on contact; a disabled drone is recaptured into the shell. A gap opens when N adjacent units are reclaimed.
  - Context: Reuses command view (6.2) and autopilot (6.1). Defender behavior is the AI racer with a target instead of a spline.
  - Acceptance: Reclaiming N adjacent units opens the trench entrance and emits `phase_complete`. Losing all fleet drones fails the job. Reproducible with a seed.
  - Out of scope: Player flying in phase 1.
  - Note: `scenes/boss/lattice_job.tscn` holds the fight: the city, the Lattice 150 m up, the crew's fleet, the pilot's own drone (frozen until the trench opens), two `Defender`s, and `LatticeFight`. A unit is tagged by staying 3.5 m from it for 0.5 s; T (`tag_unit`) sends the selected drone to the next gap unit. Each freed unit becomes a fleet drone. A defender within 1.4 m disables a fleet drone, and the shell takes back the last unit reclaimed. The four units nearest the shaft (`gap_units`) open it. Seeded through `LatticeFight.seed` (defender patrols).

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

## Epic 11: Story setup

Done when a new player learns who they are and why they fly before the first job, and joining a team feels like the turn of the story, not a dialog box. In-engine scenes over existing backdrops, not video files: the web build stays small and the look matches.

- [x] **11.1 Intro**
  - Goal: A skippable intro of about a minute on a new game: the world, the league, the real work, the home game, someone watching the leaderboards, the title. Then the job board, with the race marked START HERE.
  - Context: Beats are data (`data/story/intro.tres`): backdrop scene, camera (orbit, chase, fixed), caption, optional portrait or silhouette, arcade bezel, length. Backdrops reuse the job scenes with their HUDs hidden and nothing paid. The intro is the main scene and forwards to the board once seen; the board's Watch intro button replays it. Seven beats, 50 s: the race course, a racer chase, the cannery, the rescue fog, the home game in its bezel, an unknown viewer (Rin's silhouette), the title.
  - Acceptance: On a new game the intro plays from its first beat; finishing or any key ends it, sets the `intro_seen` flag, and opens the job board. With the flag set, launching goes straight to the board. Every beat's backdrop loads and its camera focus exists; the beats run 45 to 90 s. The board shows START HERE on the race until a job is completed or a team joined, and Watch intro replays it.
  - Out of scope: Voice, music, the recruitment scene (11.2).

- [x] **11.2 Recruitment scene**
  - Goal: Accepting Coach Rin's offer plays a short scene: she hands over a real drone, the bezel falls away, and the next job is the real thing.
  - Context: Same cutscene player and beat data as 11.1. Plays once, on accepting the first team's offer, before returning to the board. Teams carry a `joining_scene`; only Skyline Juniors has one. Five beats, 31 s (`data/story/recruited.tres`): Rin over the home game, the bezel gone and a real drone on the pad in free flight, the Act 2 card.
  - Acceptance: Accepting the Skyline Juniors offer plays the scene once; declining does not; any key skips; the board afterwards shows Act 2. Lines contain no franchise names.
  - Out of scope: Scenes for later teams.


## Epic 12: The city

Done when the sandbox is a dense desert city core instead of four orange boxes: a street grid on the flat basin, towers that rise toward downtown, rooftops worth landing on, and a map that shows it all. This is the city the Lattice will hang over in Act 5. Scene content only: buildings are static collision like the ridges, nothing here touches the flight model, assists, or grading (rules 1, 2, 8), and the terrain, golden-hour look, and job scenes are unchanged.

Decisions behind phase 1: the city is a core of about 280 m across inside the terrain's flat radius (150 m), so every building stands on y = 0 and the sandbox map bounds still fit. The street grid and buildings are generated from a seeded `CityLayout` resource (rule 4); landmarks are hand-placed later. Existing jobs keep their own maps for now.

Later phases, not yet stories: districts and landmarks (bridge, stadium, construction block, container yard); free-flight content (rooftop rings, courses with saved best times); life (drone traffic lanes, billboards, crew cameos); the city as the hub that replaces job hotkeys (decide against 5.3 first); the Lattice on the skyline by act, hidden entirely when `lattice.tres` has `enabled` false (rule 9).

- [x] **12.1 City layout and plan**
  - Goal: A `CityLayout` resource (`data/city/sandbox_city.tres`) and a pure `CityPlan` generator that turns it into streets and lots: footprint rectangle and height for every building.
  - Context: No meshes yet; this is the data every later story builds from. Layout fields: seed, core radius, block size, street width, avenue every N blocks (wider), lot subdivision range, height range with a falloff from tall downtown to low edges, and reserved clearings (centre and radius) where no lot may stand. The sandbox layout reserves a spawn plaza of at least 30 m radius at the origin and a clearing for the jammer. Generated like the terrain: deterministic per parameter set and cached.
  - Acceptance: The same layout gives an identical plan; a different seed gives a different one. No lot overlaps a street, another lot, or a reserved clearing. Every lot lies inside the core radius and inside the terrain's flat radius. Every height is within the layout's range, and the mean height of lots in the inner third of the core is greater than in the outer third.
  - Out of scope: Meshes, collision, districts, landmarks.
  - Note: The grid puts a block on the origin, not a crossing, so the plaza is a square and lots fill the ring between it and the inner third. The sandbox uses 30 m blocks, 8 m streets, and 14 m avenues (about 125 lots); the jammer clearing is 20 m at (40, -40).

- [ ] **12.2 Buildings**
  - Goal: A `City` node (`scenes/world/city.tscn`) that builds the plan into box towers with one collision box per lot and a window-grid shader.
  - Context: Towers render through `MultiMeshInstance3D` (one per mesh kind, not one node per building) so the web build stays cheap. `scenes/world/city.gdshader` draws windows in world space so the grid stays square on any building size, with per-instance tint and a sprinkle of lit windows from instance custom data; roofs read differently from walls. Uses only features GL Compatibility has. Built meshes and shapes are cached per plan, like `DesertTerrain`. Before ticking, export the web build and fly it by hand: it should hold frame rate on the sandbox.
  - Acceptance: Every lot has exactly one collision box matching its footprint and height. A ray cast down at a lot's centre hits at the lot's height. Flying the drone into a wall registers contact with `AvoidContact`. The city renders through at most 4 `MultiMeshInstance3D` nodes whose instance counts sum to the lot count. Building the same layout twice reuses the cache. The scene loads headless with no errors.
  - Out of scope: Interiors, enterable buildings, damage, night lighting.
  - Note: Built and tested, not ticked: the hand flight on the web build is still to do. The city isn't in the sandbox until 12.5, so that flight belongs with 12.5. Under GL Compatibility at 1280×720 (desktop RTX 3080) the city costs no measurable frame time: one MultiMesh, one draw.

- [x] **12.3 Streets**
  - Goal: Asphalt streets with lane markings and sidewalks, and street lights along them.
  - Context: A flat road mesh just above y = 0 with its own shader for markings; avenues get a centre line. Street lights are a `MultiMeshInstance3D` placed along street edges at a fixed spacing, each with a thin collision shape, since they are real obstacles at low altitude. Lights are unlit for now; night is a separate system.
  - Acceptance: Every street segment in the plan is covered by road mesh, and no road lies under a lot. Every street light stands on a sidewalk, outside every lot and reserved clearing, and has collision. Placement is identical for the same layout.
  - Out of scope: Traffic, signals, crosswalk props, night lights.
  - Note: `Streets` is its own scene (`scenes/world/streets.tscn`), separate from `City` so the City's four-multimesh check stays about towers; 12.5 instances both. Plan streets are now clipped to the core circle, and the plan lists `blocks`. Sidewalks and lights go only on blocks wholly inside the core, so edge lots stand on sand.

- [x] **12.4 Rooftops**
  - Goal: Rooftop clutter (AC units, water tanks, antennas) and a few rooftop landing pads, all seeded.
  - Context: Clutter is drawn through `MultiMeshInstance3D`. Anything taller than 1 m gets a collision box; antennas count. Pads go on the flattest tall roofs, carry a `MapMarker` (kind `pad`), and are the first reason to land somewhere other than the plaza.
  - Acceptance: Every clutter piece sits on its roof (base at the lot's height, inside its footprint, clear of pads). Every piece taller than 1 m has collision. The sandbox has at least three pads, each with a visible map marker. Same layout, same rooftops.
  - Out of scope: Pad-landing objectives, rings, rooftop crew.
  - Note: `Rooftops` is its own scene (`scenes/world/rooftops.tscn`), like `Streets`. Pads go on the broadest roofs at least 40% up the height range; four in the sandbox.

- [x] **12.5 Sandbox in the city**
  - Goal: The sandbox flies in the city: the four boxes are gone, the drone spawns on the plaza, the jammer stands in its clearing, and the radar and map draw building footprints.
  - Context: `scenes/debug_flight.tscn` instances `City` with the sandbox layout. `MapData` landmarks name the plaza and downtown. `TerrainImage` bakes footprints over the terrain so the radar and map show streets and blocks. The recruitment scene (`data/story/recruited.tres`) uses the sandbox as a backdrop and should now show the city; check its camera focus still exists. Sixteen tests load the sandbox; if one needs more room, grow the plaza in the layout rather than changing the test. `test_radar.gd` checks the boxes on the radar; replace that check with the rooftop pads.
  - Acceptance: The sandbox has no `Boxes` node and contains a `City`. Under the Act 1 preset the drone hovers at spawn for 5 s with no contact. The jammer test passes unchanged. The radar shows the rooftop pads, and the map image is darker under building footprints than over open street. Every existing sandbox test passes. The job hotkeys still launch every job.
  - Out of scope: Moving jobs into the city, the hub, landmarks.
  - Note: The sandbox instances `City`, `Streets`, and `Rooftops` side by side. Radar and Map take an optional `city` and bake its footprints through `TerrainImage.bake(..., footprints)`. The map's landmarks are Plaza and Downtown (the tallest tower). The full sandbox runs at 1.65 ms a frame under GL Compatibility at 1280×720 on the dev desktop; the hand flight on the web build for 12.2 is still open.
