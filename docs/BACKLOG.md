# Jaisalmer: Backlog

Stories for `/next-story`. Work them top to bottom. Epics 0 to 3 are sequential, with Epic 9 (visual baseline) done between 2 and 3; Epic 10 (navigation) follows the Epic 3 playtest, except 10.5, which waits for 4.1; 4, 5, and 7 can run in parallel after 10.4 (do 7.1 to 7.3 before 5.3, since the job board shows the roster); 6 waits for playtesting; 8 waits for 6 and 7; 12 (the city) is scene content only and can run alongside any of them; 16 (music) builds on 14 and can run alongside 15; 17 (arcade front end and crew radio) can start any time. 19 (every crew member counts) can start any time; do 19.1 before 19.2 and 19.4 before 19.5 and 19.6. 23 (gamepad) can start any time; do 23.1 first, and 23.2 before 23.3.  24 (the rename to Jaisalmer) and 25 (the epic names) wait for the owner to say go; do 25.1 before 25.2; do 24.1 before 24.2, and 24.4 needs the domain registered and its DNS pointed at GitHub.

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

- [x] **4.6 Weather in free flight**
  - Goal: A key in free flight cycles the weather: clear, then each preset in `data/weather/`, then clear again.
  - Context: Asked for after Epic 8. `Weather.apply` (moved out of `JobRunner`) puts a preset's wind on the drone and its fog on a copy of the scene's Environment; null restores the scene's own. The sandbox's `weathers` list is data; E (`cycle_weather`) cycles; the HUD subtitle names the weather. Clear brings back the sandbox breeze. Wind is only felt with the battery and wind assist off (Act 4 on), as everywhere.
  - Acceptance: E steps clear, fog bank, whiteout, clear, with each preset's fog density and wind, and the HUD names it. Back at clear the Environment is the shared golden-hour resource again, unchanged, and the drone has the sandbox breeze.
  - Out of scope: Weather on the job board, random weather, saving the choice.
  - Note: First shipped, the fog took the scene's golden colour and barely touched the sky, so it hardly read as weather. `Weather` now carries `fog_color` and `sky_affect`: the fog bank is grey and hides most of the sky, the whiteout is near white and hides nearly all of it. The rescue job's whiteout gets the same look.

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

- [x] **8.4 Phase 2: the trench**
  - Goal: The player flies the trench with the Act 5 preset while the shell contracts on a timer. Marlo calls turns from `data/dialogue/marlo.json` keyed to trench waypoints. Contact with the shell is a strike on the calling crew member.
  - Context: Reuses gates (3.1) as invisible waypoints and the strike system (7.4). Job is tagged `lethal`.
  - Acceptance: Reaching the shutter emits `phase_complete`. The shell closes the entrance after the configured time and fails the job. A shell contact strikes Marlo. Marlo's death mid-run removes callouts for the rest of the run.
  - Out of scope: Branching trench routes.
  - Note: When the entrance opens, the pilot's drone unfreezes with the job's assists and the camera rig takes it; the command view sleeps. Waypoints are invisible, collisionless `Gate`s every third point of `Lattice.trench_path()`, each called once from `marlo.json` (`trench`, by index) while Marlo lives. The shell has no physics, so contact is `Lattice.touching()` at 0.3 m. Within 2.5 m of the shell the calling crew member's `HazardZone` (Marlo, else Bea) warns; contact strikes through it, so rule 7's warning always comes first. A shell contact under a second after the warning starts lands no strike.

- [x] **8.5 Phase 3: override**
  - Goal: Hold station inside a 1 m sphere at the override port for the configured hold time while the Lattice shakes the trench and gusts wind through it. Leaving the sphere resets the hold.
  - Context: Reuses `HoldStation` from 4.4 and the wind sim from 1.7. Win condition is `hold_complete`, never damage.
  - Acceptance: A scripted perfect hold completes in exactly the hold time. Leaving the sphere for more than 0.5 s resets. Completion emits `boss_disabled` and triggers the power-down sequence.
  - Out of scope: Multiple ports.
  - Note: `OverrideHold` extends `HoldStation` and counts only in phase 3. The fight gives it a Port node on the core with the boss's `hold_radius` and `hold_time`, and grace 0.5 s. The gusts are `data/wind/lattice_gusts.tres` on the pilot's drone; the Act 5 preset already runs the wind sim, so nothing turns an assist on. The shake moves only the units' MultiMesh (look only); contact geometry stays put. Completion emits `hold_complete`, then `boss_disabled`, and moves to power-down.

- [x] **8.6 Power-down and epilogue**
  - Goal: On `boss_disabled`, the shell loosens section by section on a timeline, captured units fall free, crew-owned units return to the roster as fleet drones, and the results screen shows a final crew lines pass with living and dead accounted for.
  - Context: Reuses the results screen (2.5) and crew lines (7.3). The chorus speaks once more, then stops.
  - Acceptance: Every living crew member's drone is back in the fleet after the sequence. Dead crew members are named on the results screen and nothing of theirs returns. The save records `lattice_disabled: true`.
  - Out of scope: New game plus.
  - Note: The shell lets go in eight slices round its axis, 0.8 s apart; units fall for 1.5 s and are gone. A living crew member's lost unit becomes a fleet drone with their portrait (`LatticeFight.returned`). The job ends on the `PowerDown` objective once the sequence is over, so the results come after it. `JobResult.epilogue` holds one line per crew member: their `epilogue` line if alive, their memorial if dead. `lattice_disabled` is a story flag (save section `flags`), set only on a job that pays out. The chorus's last line is 8.7's.

- [x] **8.7 Chorus lines**
  - Goal: The Lattice's lines in `data/dialogue/lattice.json`: plural, flat, never first person singular, triggered on phase start, on reclaiming a crew-owned unit, on a strike, and on shutdown. Portrait is a grid of dots that thins as the fight goes on.
  - Context: Uses the bark system from 7.3 with a non-character speaker.
  - Acceptance: Every line passes a test that rejects "I", "me", or "my". The portrait density tracks remaining shell units.
  - Out of scope: Voice.
  - Note: `Chorus` picks lines the way `Bark` does (seeded, no repeats until a pool runs out) but is not a cast character, so it has its own `spoke` signal and `ChorusBox`. The crew-unit line fills `{name}` and `{role}`. After the shutdown line it stays silent. The portrait is a 9×9 dot grid; dots drawn = grid² × (units left / units built).

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

## Epic 13: Weather

Done when weather is layered and changing: rain, snow, fog, real wind, and lightning, each from data, blending between presets, and felt in flight as well as seen. Weather reaches the drone only through the environment sim, the same gate as wind and battery today: with the battery and wind assist on (Acts 1 to 3) the drone is shielded, so progression still removes protection rather than changing physics. Lightning is atmosphere only; it never damages a drone or strikes crew. Rendering stays inside what GL Compatibility does: CPU particles that follow the camera, and shader uniforms. Order with Epic 14: 14.1, then 13.1 to 13.4 and 13.8, then 14.2 to 14.6, then 13.5 to 13.7, then 14.7 and 14.8.

- [x] **13.1 Weather as layers**
  - Goal: `Weather` grows from fog and wind into layers: precipitation (none, rain, snow; intensity 0 to 1), temperature (°C), wind (base, gusts, turbulence, shear with height), fog (density, colour, sky cover), and storm (lightning per minute, strike distance range).
  - Context: Extends `scripts/world/weather.gd` and `Weather.apply` from 4.6. Existing presets (`fog_bank`, `whiteout`) and the rescue job keep their look and feel; new fields default to off. A `WeatherState` node in a scene holds the weather in effect, so later stories read one place.
  - Acceptance: Every new field loads from a `.tres`. The old presets apply exactly as before (fog values and wind unchanged). A scene's `WeatherState` reports the active weather after `Weather.apply`.
  - Out of scope: Particles, sound, physics effects.
  - Note: `Weather` adds `precipitation` (`Weather.Precipitation` NONE/RAIN/SNOW), `intensity`, `temperature` (default 15 °C, no effect), `lightning_per_minute`, and `strike_distance` (Vector2 min/max m); fog keeps `fog_density`, `fog_color`, `sky_affect`; `Wind` adds `turbulence` and `shear` (power-law exponent), both 0 and not yet used by `Wind.sample` (13.4). `Weather.apply` sets `WeatherState.of(scope).weather`, which finds a `WeatherState` under the scope or adds one, and emits `changed`; read it with `WeatherState.of(node)`.

- [x] **13.2 Rain**
  - Goal: Rain that reads as rain: streaks around the camera at a density set by intensity, the ground, streets, and roofs going dark and glossy as it falls, and drops on the lens in FPV.
  - Context: A `CPUParticles3D` box parented to the active camera, so it costs the same anywhere. Wetness is a global shader uniform that the terrain, city, and street shaders read and that ramps up while it rains and dries after. The lens drops are a screen overlay in FPV only.
  - Acceptance: Particle amount scales with intensity and is zero with no rain. Wetness rises over about 10 s of rain and falls back to 0 after it stops. The shared golden-hour Environment and the shader resources are not modified on disk.
  - Out of scope: Puddles, splashes, rain sound.
  - Note: `WeatherState` adds a `Rain` child that reads its weather each frame: `CPUParticles3D` streaks (`max_amount` 2400 times intensity, freed with no rain) parented to `get_viewport().get_camera_3d()`, a `wetness` global shader uniform (declared in `project.godot` `[shader_globals]`, ramping over `wet_time` 10 s and drying over `dry_time` 20 s; `Rain.advance(delta)` steps it in tests), and a `LensDrops` CanvasLayer (`scenes/world/lens_drops.gdshader`) shown only in FPV. The city, street, and desert shaders declare `global uniform float wetness`; snow cover (13.3) can follow the same pattern and could share Rain's camera-following setup.

- [x] **13.3 Snow**
  - Goal: Snow that drifts with the wind and builds up white on the ground and roofs, then melts away when it stops.
  - Context: Same camera-following particles as rain, slower and carried by the scene's wind sample. Cover is a global shader uniform like wetness, read on upward-facing surfaces.
  - Acceptance: Flakes move with the wind's direction. Cover rises while it snows and returns to 0 after. Snow and rain together are rejected by validation.
  - Out of scope: Snow on the drone, footprints, snow sound.
  - Note: `WeatherState` adds a `Snow` child beside `Rain`: `CPUParticles3D` flakes (`max_amount` 1600 times intensity, freed with no snow) on the camera via the shared static `Rain.follow_camera`, launched along `Snow.flake_velocity()` (1.5 m/s fall plus `weather.wind.sample`, visual only), and a `snow_cover` global shader uniform (in `project.godot`) that builds at intensity / `cover_time` 30 s and melts over `melt_time` 30 s; city roofs, streets, and flat desert whiten with it. `Weather.validate()` returns problems: a stored precipitation of RAIN | SNOW (3) is "rain and snow together", plus intensity outside 0..1 and a backwards strike range; 13.7 can validate presets with it.

- [x] **13.4 Real wind**
  - Goal: Wind that varies the way air does: turbulence on top of gusts, stronger with height, and calmer in the lee of buildings.
  - Context: All of it in `Wind.sample`, which the flight model already reads (rule 1 unchanged). Shear is a power law with height. Shelter uses the city's plan: a point downwind of a lot and below its height gets a reduced wind. Seeded turbulence.
  - Acceptance: With shear set, measured wind at 40 m exceeds wind at 5 m. A point in the lee of a tower gets less wind than one upwind of it at the same height. The same seed gives the same turbulence.
  - Out of scope: Updrafts, wind visualisation.
  - Note: `Wind.sample(time, at := (0, 10, 0), plan: CityPlan = null)` scales base, gusts, and seeded turbulence (`Wind.seed`, a few sines per axis drifting with place) by `(height / REFERENCE_HEIGHT 10 m) ^ shear`, and by `Wind.shelter`: down to 0.3 just downwind of a lot taller than the point, recovering over 4 lot heights. `City` joins `City.SHELTER_GROUP` and `Drone.wind_velocity()` samples at its own position in that city's local space (still gated by `intent.environment_sim`); calls without a point (snow flakes, old presets) get the reference-height wind unchanged.

- [x] **13.5 Lightning**
  - Goal: Lightning in storms: a flash that lights the sky and the scene for a moment, and a bolt in the distance, at a seeded rate.
  - Context: Each strike is an event with a position and time (14.7 uses it for thunder). The flash briefly raises the sky and ambient light; the bolt is a short-lived line mesh. Atmosphere only: nothing is hit or harmed.
  - Acceptance: Strike times and positions repeat with the seed. A strike raises ambient light then returns it within 0.5 s. No strike lands inside the strike distance's minimum.
  - Out of scope: Damage, strikes on drones or crew.
  - Note: `WeatherState` adds a `Lightning` child: strikes come at `lightning_per_minute` (exponential waits, min 0.25 s) seeded by the new `Weather.storm_seed`, at a random bearing and a distance inside `strike_distance` around the scope's origin; `Lightning.plan(w, seconds, centre)` returns the same schedule the node plays. Each strike emits `struck(Lightning.Strike)` (`time` since the storm began, world `position`) for thunder (14.7), flashes ambient and sky energy on the per-scene Environment copy (x2.5, back over `flash_time` 0.35 s), and shows a camera-facing ribbon bolt for 0.2 s; a seed change or storm start restarts the schedule, rate changes apply from the next strike.

- [x] **13.6 Changing weather**
  - Goal: Weather that changes: a scene can blend from one preset to another over a set time, and a job can name a sequence (clear, then fog rolling in).
  - Context: `WeatherState` blends every numeric field linearly and swaps precipitation type at the midpoint (intensity crosses zero there). Free flight's E blends over 3 s instead of snapping.
  - Acceptance: Halfway through a blend every numeric field is halfway between the two presets. A job's sequence runs on its schedule. E in free flight reaches the next preset after the blend time.
  - Out of scope: Forecasts, weather on the map.
  - Note: `Weather.blend(a, b, t, clear_env, into)` lerps every number, colour, and wind field (null is `Weather.new()`; rain/snow swap at t 0.5 through zero intensity; "keep the scene's" fog colour and sky cover resolve against the clear Environment), and `WeatherState.blend_to(to, seconds, drone, scope)` applies each step with `Weather.apply` (which now reuses the scene's Environment copy), lands on `to` itself, and emits `blended`; `advance(delta)` steps it in tests. `Job.weather_changes` is an `Array[WeatherChange]` (`at` s of live time, `weather`, `blend_time`) that `JobRunner` starts on schedule; free flight's E blends over `weather_blend_time` 3 s. Rain and snow only change particle amount on steps over 1/16 of `max_amount` (each change restarts the emitter); a storm blending in from 0 rolls its first strike at the low early rate, so 13.7 sequences may want to start lightning at a nonzero rate.

- [x] **13.7 Presets and placement**
  - Goal: A useful set of presets and weather on more jobs: light rain, storm, blizzard, fog bank, clear, and the rescue's whiteout.
  - Context: Data in `data/weather/`. Free flight's E cycles them all. Jobs pick weather that suits them (demolition in light rain, the relay in a storm). Weather never makes a job impossible at its act's preset.
  - Acceptance: Every preset loads and validates. Each job's weather is set in its `.tres`. Every job with weather still completes in its existing test.
  - Out of scope: Random weather.
  - Note: `data/weather/` holds `clear`, `light_rain` (rain 0.35, 12 °C), `storm` (rain 0.85, lightning 4/min, seed 7), `blizzard` (snow 0.9, −8 °C), `fog_bank`, and `whiteout` (unchanged), all passing `Weather.validate()`. Free flight's E cycles fog bank, whiteout, light rain, storm, blizzard, then clear (its own sky and breeze at index −1, so `clear.tres` is for jobs and sequences, not the cycle); tests that want clear loop `cycle_weather` until `weather_index` is −1. Demolition (Act 3, shielded) flies in light rain, the Team relay (`fleet_race`, Act 5) in the storm, and the rescue keeps the whiteout; `Weather.apply` only reaches the player's drone, so the relay's fleet drones do not feel the storm.

- [x] **13.8 Weather in the flight model**
  - Goal: Weather the drone feels beyond wind: rain adds drag and load, cold shortens the battery, and wet snow below freezing ices the props, costing thrust until it clears.
  - Context: New environment inputs to the one flight model in `drone.gd`, active only when `intent.environment_sim` is on, exactly like wind and battery today; the battery and wind assist shields them through Act 3. Rain: extra drag scaled by intensity. Cold: battery capacity falls below 10 °C. Icing: accumulates in snow below 0 °C, reduces max thrust up to a cap, and sheds when out of snow or warmer. The HUD shows an ICING chip.
  - Acceptance: With the sim on, heavy rain lowers top speed measurably; −10 °C drains the battery faster than 20 °C; icing builds in snow, lowers climb rate, and sheds after. With the battery and wind assist on, none of these change anything.
  - Out of scope: Water damage, crashes from weather alone.
  - Note: `Weather.apply` now also sets `Drone.weather`; the drone reads it only with `intent.environment_sim` on: rain adds `rain_drag` (0.15 N per m/s) and `rain_load` (0.3 N) times intensity, `battery_capacity()` falls 2% per °C below 10 °C (floor 0.4), and `icing` (0..1) builds at intensity / `ice_build_time` 20 s in snow below 0 °C, sheds over `ice_shed_time` 8 s, and caps `iced_max_thrust()` at 30% loss. `reset` clears ice; `FlightHud.icing_shown()` draws the ICING chip left of the battery. Code that sets `drone.wind` directly (debug breeze, Lattice gusts) leaves `drone.weather` alone.

## Epic 14: Sound

Done when everything that happens has a sound. Sounds are files, not live synthesis: the web build has no threads, so it plays samples only and live bus effects are out; anything filtered (snow's muffled mix) is baked. Two sources: `tools/sfx/` generates most effects from a checked-in script (deterministic, no licence), and CC0 recordings cover what synthesis does badly (rain, thunder, wind, rain on a roof). `data/audio/LICENSES.md` lists every file with its source and licence. Sound is never needed to play: every cue that matters already has a visual. No music yet.

- [x] **14.1 Sound foundation**
  - Goal: A `Sfx` autoload that plays named events from data, buses for master, flight, world, weather, UI, and voice, and volume sliders plus a mute key saved with the settings.
  - Context: A `SoundBank` resource maps an event id to one or more streams with volume, pitch variation, and bus. `Sfx.play(id, at := null)` picks a stream (2D, or 3D at a position) and logs the event so headless tests can assert on it. Settings section of the save holds the volumes. The web build starts audio on the first input (the intro's any key).
  - Acceptance: Playing a known event logs it with its bus. An unknown event warns without crashing. Volume and mute save and reload. Every file under `data/audio/` is listed in `LICENSES.md` as generated or CC0.
  - Out of scope: Any specific sound.
  - Note: Buses live in `default_bus_layout.tres` (Master, Flight, World, Weather, UI, Voice). `Sfx` keeps 12 flat players and makes a self-freeing 3D player per placed sound. Volumes are linear 0..1 per bus in `GameSettings.volumes`, saved with `muted` in the settings section; N mutes, and the board has a Sound dialog. `SaveGame.load_all` reapplies them. The bank (`data/audio/bank.tres`) and `LICENSES.md` start empty.

- [x] **14.2 The drone**
  - Goal: Each drone sounds like a drone: motor hum whose pitch and level follow its motors' thrust, prop wash near the ground, and impacts by speed.
  - Context: Generated motor loop, pitched per drone from thrust (the same reading `DroneLook` uses). 3D players so AI racers and the fleet are heard around you. One impact per contact, scaled by impact speed.
  - Acceptance: Pitch rises with thrust and falls at idle. A contact plays exactly one impact, louder when faster. A frozen drone is silent.
  - Out of scope: Doppler, per-motor sound sources.
  - Note: `tools/sfx/generate.py` (stdlib, fixed seeds) writes `data/audio/generated/`; loops carry a RIFF `smpl` chunk because `*.import` is gitignored, so add `loop=True` rather than editing import settings. Each drone has a `Sound` node (`DroneSound`): hum and wash `AudioStreamPlayer3D`s on the Flight bus, state exposed as `humming`, `hum_pitch`, `hum_db`, `washing`, `impacts`; it turns on `contact_monitor` and plays `drone_impact` once per body contact. `Sfx.play(id, at, gain_db)` now takes a gain, logged as `gain_db`.

- [x] **14.3 Flight events**
  - Goal: Sounds for what the pilot needs to notice: crash recovery, low battery, an assist cutting in (guard, brake), and changing camera view.
  - Context: Hooks on existing signals; each plays once per event.
  - Acceptance: Each event plays its sound once and only on its event.
  - Out of scope: Voice warnings.
  - Note: `FlightCues` (`scripts/audio/flight_cues.gd`) is a child of `camera_rig.tscn`, so every flying scene gets it and it follows the rig's target drone; it plays `flight_recovered`, `flight_low_battery` (battery crosses 0.2, the HUD's red), `flight_guard` (`CollisionGuard.braking`), `flight_brake` (new `Brake.stopping`: sticks released above `stop_speed`), and `camera_view` (UI bus, only when the view really changes). Assist cues count a flicker as one event until the assist has been out for `rearm_time`; switching target drones is never an event.

- [x] **14.4 Jobs**
  - Goal: Jobs sound like jobs: countdown beeps, gates passed, hold progress, finish and fail stingers, the payout count, and the hazard warning and strike.
  - Context: `JobRunner` state changes, `Course` gates, `HoldStation` progress, `HazardZone` warnings and strikes, the results screen.
  - Acceptance: Every runner state change and every hazard warning and strike plays its sound. Gate sounds match gates passed.
  - Out of scope: Commentary.
  - Note: `JobRunner` adds a `JobCues` (`scripts/audio/job_cues.gd`) as an internal child, so every job gets its sounds without scene edits and `objectives()` never sees it: a `job_*` cue per state entered, a `job_countdown` beep per whole countdown second, `job_gate` for each `Course.gate_passed` by `runner.drone` or the rig's target (not AI racers), `job_hold_tick` per quarter of each `HoldStation` and `job_hold_done`, and `hazard_warning` / `hazard_strike` from every `HazardZone`. The results screen plays `job_payout` when pay is above zero. `hazard_strike` is on the World bus; every other job cue, `hazard_warning` included, is on the UI bus.

- [x] **14.5 Interface**
  - Goal: The board, shop, pilot select, offers, and dialogs click, focus, and confirm.
  - Context: A small helper that wires any `Button` to UI sounds, so new screens get them too.
  - Acceptance: Every button on the board and its dialogs plays a click when pressed.
  - Out of scope: Menu music.
  - Note: `UiSounds.wire(root)` (`scripts/audio/ui_sounds.gd`) adds an internal node that wires every `BaseButton` under `root`, now and as nodes enter later (rebuilt rows, dialogs' internal OK/Cancel): `ui_click` on press, `ui_focus` on keyboard or pad focus (not while the mouse is down), and `ui_confirm` on each `AcceptDialog.confirmed`; a meta flag keeps nested wiring from doubling. `JobBoard` and `JobRunner` (its launch and leave dialogs and the results screen) call it; any new screen just calls it too. All three cues are on the UI bus.

- [x] **14.6 The world**
  - Goal: Places sound like places: city hum, desert wind, the demolition's debris, the job board's room tone.
  - Context: Ambience loops per scene on the world bus; debris impacts from the demolition's `Debris`.
  - Acceptance: Every flying scene has an ambience playing. Debris impacts play one sound each.
  - Out of scope: Traffic, crowds.
  - Note: `Ambience` (`scripts/audio/ambience.gd`, an `AudioStreamPlayer` with an `event` id) plays a bank loop on its event's bus from `_ready`; one sits in `desert.tscn` (`desert_wind`), `city.tscn` (`city_hum`, layered over the desert wind), and `job_board.tscn` (`room_tone`), all on the World bus, so any scene built on those places sounds like them. `Debris` now turns on `contact_monitor` and plays `debris_impact` (3D, gain by speed change) once per contact above `quiet_impact` m/s; it stays silent while frozen, leaves drone contacts to `DroneSound`, and between two loose pieces only one plays. 14.7 can add weather loops the same way or crossfade against `Ambience.volume_db`.

- [x] **14.7 Weather sound**
  - Goal: Weather you hear: rain that grows with intensity, rain drumming on a roof when the drone is under one, wind that follows the measured wind speed, snow that hushes the mix, and thunder after each lightning flash.
  - Context: CC0 rain, wind, and thunder recordings. Thunder waits distance / 343 s after its strike (13.5). Snow's hush is a baked, filtered copy of the ambience crossfaded in, not a live filter.
  - Acceptance: Rain level follows intensity. Thunder plays after its flash, later the farther the strike. The wind loop's level follows the drone's measured wind.
  - Out of scope: Rain on the lens sound.
  - Note: `WeatherState` adds a `Sound` child (`WeatherSound`, `scripts/audio/weather_sound.gd`) with loops on the Weather bus: `weather_rain` at `rain_level` = intensity, crossfading over `roof_time` 0.5 s to `weather_rain_roof` while an upward ray from the drone hits a body within `roof_height` 60 m; `weather_wind` at `wind_level` = speed of the new `Drone.measured_wind()` / `full_wind` 14 m/s (the air at the drone, heard even while the battery and wind assist shields it; `wind_velocity()` is that gated by the sim), pitch rising with it; and `thunder` (three CC0 variants) as a flat cue `thunder_delay(distance)` = distance / 343 s after each `Lightning.struck`, measured from the drone (else the camera, else the scope), quieter with distance. The drone is `WeatherSound.drone`, else the camera rig's target. Snow's `hush` (intensity, over `hush_time` 3 s) crossfades `Ambience` and the wind loop to baked copies named by the new `SoundEvent.muffled` / `muffled_db` (`generate.py` writes `city_hum_muffled` and `desert_wind_muffled`; the CC0 wind's copy is ffmpeg low-passed). CC0 files sit in `data/audio/cc0/` as mono 22050 Hz Ogg, with `loop` set in code since `.import` is not checked in.

- [x] **14.8 Crew and story**
  - Goal: The crew and the Lattice are heard without voice acting: a short chirp under each bark, the Lattice's low drone and chorus tones, its power-down, and sound beds under the cutscenes.
  - Context: Generated per-character chirps (pitch from data in `Character`). The chorus plays a tone under each line and stops for good after shutdown.
  - Acceptance: Every bark plays its speaker's chirp. Every chorus line plays a tone, and none after shutdown. Each cutscene has a bed.
  - Out of scope: Voice acting, music.
  - Note: `Character.chirp_pitch` (data, validated 0.5..2) pitches one `crew_chirp` sample (Voice bus); `Bark` chirps on every `spoke` (including lines emitted straight onto it), `Bark.chirp(id)` is silent for the dead, and the results screen chirps its bark and injured casualty lines (epilogue rows do not). `Chorus.say` plays `lattice_tone` (Voice) per line, so nothing after shutdown; `LatticeSound` (child of the Lattice in `lattice_job.tscn`) loops `lattice_drone` and on `boss_disabled` stops it for good and plays `lattice_power_down` once. `Cutscene.bed` names a loop (`bed_intro`, `bed_recruited`, World bus) that `CutscenePlayer.bed` plays until `finish()`; `Sfx.play` now takes a `pitch` scale, logged as `pitch`.

## Epic 15: Grounded realism

Done when the city, desert, and obstacles read as real places at drone height: real materials in the golden-hour palette, buildings and streets with the detail real ones have, clutter at street level, and lighting that sits them in the scene. The target is grounded realism, not strict photorealism; the golden-hour look stays. Two tiers: the web build (GL Compatibility) gets everything done in materials, geometry, and shaders, and a desktop High tier adds what only Forward+ has (SSAO, SSIL, SSR, SDFGI, volumetric fog). Assets are CC0 only, from ambientCG and Poly Haven, each listed in `data/LICENSES.md` with its source URL; downloads are images and glTF only, nothing executable. The epic adds at most 25 MB to the web build, checked by a test. Scenery only: collision follows the visible shape, flight and grading never change, and every job's existing test still completes. The web frame rate is checked by hand alongside 12.2 before 15.5 and again at the end.

- [x] **15.1 Quality tier**
  - Goal: A Quality setting (Low, High) saved with the settings, picking which renderer extras each scene's Environment and lights use. High is the default on desktop; the web build is always Low.
  - Context: `GameSettings` gains `quality`, saved in the settings section like `volumes`; the board's settings gain a Quality choice (hidden on web). A static `Quality.apply(env, sun)` turns on SSAO, SSIL, SSR, SDFGI, and volumetric fog, and longer, softer sun shadows, only when the renderer is Forward+ and quality is High; it works on the per-scene Environment copy, as `Weather.apply` does. Weather fog maps onto volumetric fog on High.
  - Acceptance: Quality saves and reloads. On High under Forward+ every extra is on; on Low, or under GL Compatibility, every extra is off. The shared `golden_hour.tres` is not modified on disk. Weather fog still applies on both tiers.
  - Out of scope: Resolution scaling, per-feature toggles.
  - Note: `scripts/world/quality.gd` (`Quality.apply(env, sun, tier, renderer)`, `Quality.fog(env)`) sets SSAO, SSIL, SSR, SDFGI (energy 1.6), volumetric fog, and a 600 m, 1.2-degree soft sun shadow on High under Forward+, and turns them off otherwise; `golden_hour.gd` gives every scene its own Environment copy with the tier applied, so `clear_environment` is that copy, not the shared `golden_hour.tres` (which still has `ssao_enabled` on disk; Quality overrides it). `Weather.apply` calls `Quality.fog` so weather fog drives volumetric density (0.5 x fog density) and colour on High; 15.3 should tune its grade against both tiers, and later stories should set sun shadow values on the scene before `_ready` so Low keeps them.

- [x] **15.2 Material library**
  - Goal: About ten CC0 surface sets at 1K (colour, normal, roughness, packed where possible): concrete, brick, metal cladding, glass, stone paving, asphalt, kerb stone, sand, rock, and painted metal, in `data/materials/`.
  - Context: From ambientCG and Poly Haven, checked CC0 page by page as the audio was. `*.import` is gitignored, so textures import on the defaults: VRAM-compressed with mipmaps once a 3D material uses them; any import change goes in code or un-ignores that one file, decided here. A `SurfaceSet` resource names each set's maps and its real-world tile size in metres.
  - Acceptance: Every set loads and names existing textures. Every file under `data/materials/` is in `data/LICENSES.md` as CC0 with a URL. A size test fails if `data/materials/` plus `data/models/` exceeds 25 MB.
  - Out of scope: Using the sets anywhere.
  - Note: `SurfaceSet` (`scripts/world/surface_set.gd`; `SurfaceSet.named(id)`, `SurfaceSet.ids()`) has `albedo` (sRGB; null for glass), `normal_rough` (R, G = OpenGL normal X, Y with Z rebuilt, so `NORMAL_MAP = vec3(nr.rg, 1.0)` works; B = linear roughness), `tile_size` in metres, and `metallic`; the ten sets are `data/materials/<id>.tres` (concrete, brick, cladding, glass, paving, asphalt, kerb, sand, rock, painted_metal), ambientCG 1K repacked to 6.4 MB of JPG and listed in `data/LICENSES.md`. Their `.import` files are un-ignored and checked in (VRAM compressed, mipmaps, 3D detection off, normal-map detection off for `*_nr.jpg` so a `hint_normal` sampler cannot turn them into two-channel RGTC and drop roughness), so a new art file needs its `.import` committed too; only S3TC is imported (no ETC2/ASTC), so mobile web would decompress on load. `tests/test_material_library.gd` checks sets, imports, licences (texture and model files under `data/materials/` and `data/models/`), and the 25 MB budget.

- [x] **15.3 Light and grade**
  - Goal: Golden hour that looks lit rather than flat: AgX tonemapping with tuned exposure, a colour grade, glow kept to hot spots (sun, lit windows, wet highlights), and sun shadows that are crisp near the drone and soft far out.
  - Context: `data/world/golden_hour.tres` (ACES and glow today) and the sun in `golden_hour.tscn`. Grade via the Environment's adjustments, which GL Compatibility supports. Fog, rain, snow, and lightning presets are rechecked against the new tonemap.
  - Acceptance: The Environment uses AgX and the tuned values. Shadow cascade split and distance are set from data. Every weather preset still applies and lightning's flash still raises and returns ambient light.
  - Out of scope: Time of day, the desktop extras (15.1).
  - Note: `golden_hour.tres` now uses AgX (exposure 1.25, white 16, contrast 1.35), glow only above HDR 1.2 with no bloom, and a grade from adjustments plus a `GradientTexture1D` split-tone curve (cool shadows, warm highlights); the sun is warmer (1, 0.66, 0.4) at 1.8 and ambient drops to 0.65 so lit and shaded faces separate. `SunShadow` (`data/world/sun_shadow.tres`, set on `GoldenHour.shadow`) lays out 4 PSSM cascades (0.05/0.15/0.4 of a 250 m reach) and stores High's reach and sun size as sun meta that `Quality.apply` reads, so call `SunShadow.apply` before `Quality.apply`. Sunlit walls read pale cream under AgX because `city.gdshader`'s wall albedo is 0.86; 15.4's real materials should sit darker (albedo about 0.4-0.6) to keep colour in the light.

- [x] **15.4 Building surfaces**
  - Goal: Towers in real materials: each building picks concrete, brick, cladding, or stone from its seed, mapped in world space so nothing stretches, with grime streaks under ledges, dust at the base, shader ambient occlusion where walls meet the ground, and roof stains.
  - Context: `scenes/world/city.gdshader` and `City`; custom data already carries a per-building seed. Triplanar or world-space UVs at each set's tile size. Wetness darkens and glosses and snow cover whitens, as now.
  - Acceptance: Each lot's material comes from its seed and repeats with it. Every material in use comes from the 15.2 library. Wetness and snow cover still change the shader's output. The plan and collision are unchanged.
  - Out of scope: Window glass (15.5), building shape (15.6).
  - Note: `City.walls` (concrete, brick, cladding, kerb granite as stone; the shader holds four) and `City.roof` (concrete) are `SurfaceSet`s set in `city.tscn`; `City._apply_surfaces` hands their maps, tile sizes, and metallic to `city.gdshader`, and each lot's set is `City.wall_for(seed)` from its custom-data seed, passed as `INSTANCE_CUSTOM.z` and kept in `City.seeds` / `City.wall_index` since MultiMesh data cannot be read back. The shader maps walls along z or x by world y and roofs by xz with a matching TANGENT/BINORMAL set in vertex(), adds grime under sills and the roof edge, base dust and AO, roof stains, then applies wetness and snow to every surface at the end; window code is unchanged for 15.5. `tests/city_render_probe.gd` is a GL Compatibility render run as a child process by `tests/test_building_surfaces.gd` (needs a display), which 15.5 can reuse for its compile check.

- [x] **15.5 Windows**
  - Goal: Windows that read as glass with rooms behind them: sky reflection in the pane, fake interiors that shift in perspective as you move, blinds and lights varying per window, and lit windows glowing after dark-toned weather.
  - Context: The window grid in `city.gdshader`, already in world space with `flat` varyings. Interior mapping draws a room box from a small atlas, cheap enough for GL Compatibility; reflection uses the sky colour and a Fresnel term, not a probe.
  - Acceptance: The lit fraction per building stays within `lit_min` to `lit_max`. Window choice per cell repeats with the seed. The shader compiles under GL Compatibility (checked by loading the city with the compatibility renderer in the test run).
  - Out of scope: Real interiors, reflection probes.
  - Note: Windows are whole cells centred on each face (`City.window_cell`, `ground_floor`, pushed to the shader; `City.window_grid`/`window_count` count them), each a frame, an optional blind, and glass that adds a Fresnel sky-gradient reflection to an interior-mapped room from a const room atlas, with lamps that glow harder as `wetness` rises. Custom data is now (weathering seed, lit window count, wall set, window seed), whole numbers below 2048, and the shader lights exactly the first `lit_counts[i]` ranks of a keyed shuffle, mirrored bit for bit by `City.window_at` (keep `hash32`/`window_rank` and `_hash32`/`_rank` in step); `tests/city_render_probe.gd` now also logs engine errors, which `tests/test_windows.gd` uses as the GL Compatibility compile check. GL Compatibility crushes low emission far more than Forward+ (emission 0.1 shows as about 0.02 vs 0.38), so unlit panes read dark on web and milky on desktop: 15.3's tonemap work should even this out, and 15.6 must keep window faces axis-aligned boxes or extend the grid per part.

- [x] **15.6 Building shapes**
  - Goal: Buildings that are not boxes: podiums with towers above, setbacks, parapets, ledges every few floors, and rooftop plant rooms, all from the same seeded plan, so every tower differs.
  - Context: `CityPlan` gains a shape per lot (a list of stacked boxes plus trims); `City` draws each part kind through its own MultiMesh and builds collision from the stacked boxes, so the drone can land on a setback. `Rooftops` pads move to the top box; the radar footprint stays the ground lot.
  - Acceptance: The same seed gives the same shapes. No part leaves its lot. Collision matches each stacked box. Wind shelter (13.4) uses each lot's tallest height as before. Every job and race test still completes.
  - Out of scope: Curved or angled buildings.
  - Note: `CityPlan.shapes[i]` (`CityPlan.Shape`) holds each lot's stacked `boxes` (AABBs, street up; the top box's roof is `heights[i]`, which is unchanged, as are `lots`), `trims` with `trim_kinds` (`CityPlan.Trim` PARAPET, LEDGE, PLANT; plant rooms stand above `heights[i]`), and `roof_clear` (top roof minus the plant room), from their own rng (seed + 3) with storey lines from the layout's new `ground_floor`/`storey`; walls above a podium, or every wall without one, stand 0.3 m in so ledges stay on the lot. `City` draws Towers, Parapets, Ledges, PlantRooms MultiMeshes (trims use a copy of the material with `trim` set: no windows or foot AO), collides every stacked box then every plant room, and keeps windows per part (`City.parts`, `part_lot`; `window_at(part, k)`, `window_grid(size, base)`), the shader counting whole storeys inside each box from its base. `Rooftops` puts clutter on the top box clear of plant rooms and pads at `roof_clear`'s centre; 15.9 should place wall clutter against `parts`, not lots, and keep off ledges and parapets.

- [x] **15.7 Streets**
  - Goal: Streets with what real ones have: raised kerbs and pavements, crosswalks at every crossing, lane arrows, patches and cracks, manholes, and drains, on textured asphalt.
  - Context: `Streets` and `streets.gdshader`. Kerbs are geometry (a thin MultiMesh along each block edge, with collision); markings, patches, and manholes are shader decals placed from the plan's seed, wet and snowed like the rest.
  - Acceptance: Every block has a kerb on each street side. Every crossing has crosswalks. Decal placement repeats with the seed. Wetness and snow still apply.
  - Out of scope: Traffic lights, moving traffic.
  - Note: `Streets` now raises each drawn block's pavement to `kerb_height` (0.15 m) behind four kerb boxes (`Streets.kerbs`, the Kerbs MultiMesh), all colliding, and `streets.gdshader` draws road, pavement, and kerb from the asphalt, paving, and kerb sets by a `layer` uniform. Road segments are cut into chunks of at least `chunk_length` whose CUSTOM0-3 vertex data carry crosswalks, stop lines, arrows, patches, manholes, and drains (`Streets.crosswalks`, `Streets.decals` = [Mark kind, XZ rect, chunk], seeded from layout.seed + 5; keep `_markings` and the shader in step), and `tests/streets_render_probe.gd` is the GL Compatibility render check. 15.9 should place kerbside clutter on the pavement inside `kerbs` (top at `kerb_height`, not 0), keep out of road pieces, and may avoid `decals` drains.

- [x] **15.8 Desert ground**
  - Goal: Desert that reads as desert: textured sand and rock blended by slope and height, scattered rocks, scrub, and cacti in bulk, and dust blowing with the wind.
  - Context: `DesertTerrain` and `desert.gdshader`; scatter through MultiMesh seeded from the terrain, kept off the city core, roads, clearings, and course lines. Rocks above knee height collide; scrub does not. Dust is camera-following CPU particles like rain, carried by `Wind.sample`.
  - Acceptance: Scatter repeats with the seed and never lands in the city core, a clearing, or within a gate's radius of a course. Dust density follows wind speed and is zero in still air.
  - Out of scope: Wildlife, vegetation sway.
  - Note: `desert.gdshader` now samples the 15.2 sand and rock sets (fed from `DesertTerrain.sand_set`/`rock_set`) at two scales, rock triplanar, tinted toward the old palette by `palette_amount`; a `Scatter` child (`DesertScatter`, procedural meshes, no new art files) places about 8000 rocks, 18000 scrub, and 900 cacti from the terrain seed in 300 m MultiMesh chunks with visibility ranges, kept off every `City` core (+ avenue width) and clearings and every `Course` line (gate half-diagonal) found under the Ground's owner by `DesertScatter.keep_outs`, and colliders (cacti, rocks topping 0.5 m) stay outside the flat area so jobs are untouched. A `Dust` child (`DesertDust`) puts wind-carried CPU puffs on the ground under the active camera, reading the scene drone's `wind` (or its own `wind` export); vertex colours read wrong on these MultiMeshes under GL Compatibility, so scatter colour comes from material uniforms, and particle billboards need `billboard_keep_scale` for `scale_amount` to show.

- [x] **15.9 Street clutter**
  - Goal: The city at drone height: parked cars, bus shelters, benches, lamp posts, signs, trees in pits, and AC units and pipes on walls.
  - Context: CC0 glTF models from Poly Haven in `data/models/`, inside the 25 MB budget, drawn through MultiMesh per model and placed from the plan's seed along kerbs and on walls. Anything taller than a bench collides with a simple box. Clearings and rooftop pads stay clear.
  - Acceptance: Placement repeats with the seed. Nothing sits in a street lane, a clearing, or on a pad. Every model is in `data/LICENSES.md`. Every job and race test still completes.
  - Out of scope: Animated or interactive props.
  - Note: `StreetClutter` (`scenes/world/street_clutter.tscn`, a child of `streets.tscn` that reads its parent `Streets`) draws one MultiMesh per kind (`StreetClutter.Kind`: CAR, BENCH, SHELTER, SIGN, TREE, PIT, AC, PIPE) from seed + 9 and lists each piece as {kind, xform, box, lot} in `pieces`; cars sit in `parking` strips `park_width` deep against the kerb (avenues both sides, streets one), clear of crosswalks and lane arrows, and `lanes` is the rest of the road. Pieces taller than the bench model collide with their AABB; models are reworked Poly Haven glTF in `data/models/<model>/` (1.3 MB, texture `.import` files un-ignored and checked in), the tree a low-poly card tree from a rendered leaf atlas; the clutter uses StandardMaterial3D, so `wetness` and `snow_cover` do not reach it, and the existing street lights stay as the lamp posts.

- [x] **15.10 Obstacles as structures**
  - Goal: Race gates, the inspection tower, the demolition's structures, and job props built as real objects (truss frames, beams, signage, lights) instead of plain boxes.
  - Context: `Gate`, the job scenes (`inspection.tscn`, `demolition.tscn`, and the rest), and `Debris`. New meshes are visual; each keeps its existing collision shape and size, so courses and jobs play exactly as before. Debris pieces use the 15.2 materials.
  - Acceptance: Every gate and job prop keeps its collision shape and transform. Every job and race test still completes. No job scene still draws a bare `BoxMesh` for a structure.
  - Out of scope: New obstacles, changes to courses.
  - Note: `Structure` (`scripts/world/structure.gd`, a MeshInstance3D with `kind`, `size`, `surface`, `tint`/`paint`, `grime`, trim and lamp colours) builds a cached procedural mesh (PANEL, BLOCKS, PIER, BEAM, TRUSS, DECK, WALL) that stays inside its collision box, drawn with `structure.gdshader` (15.2 sets triplanar in object space so debris keeps its texture, rain streaks from vertex COLOR.r, ground dust, `wetness`/`snow_cover`); gates are black box trusses with an LED strip, a numbered banner (Label3D), and the same `_glow` highlight, and the inspection tower, cannery (brick `WALL`s with concrete bands, concrete slabs and debris), and delivery walls and piers now use it. Collision nodes, bodies, masses, and transforms are unchanged (`tests/test_obstacle_structures.gd` fingerprints them per job scene), so a later prop should put a `Structure` beside its `CollisionShape3D` at the same size and transform; the jammer mast and drop pad (cylinders) are unchanged.

## Epic 16: Music

Done when every act has its own score, all built from one original mantra over one held drone note, and the music strips back as the assists come off: Act 1 is fully produced mantra pop, and by the Lattice it is a bare voice over the drone. Music follows the Epic 14 rules: it is generated offline and baked, never synthesized live (the web build has no threads). `tools/music/generate.py` (stdlib, fixed seeds, deterministic) writes WAV stems, and ffmpeg encodes them to Ogg Vorbis in `data/music/`, as it already low-passes the CC0 wind. The WAV intermediates are not checked in. Each score is a set of same-length stems. Plain `AudioStreamPlayer`s start them on the same frame, and the music changes only by fading stem volumes, never by live filters. `AudioStreamSynchronized` and `AudioStreamInteractive` stay out until the web build is shown to play them. The whole game uses one key, and the drone's motor hum is tuned to its tonic. Melodies are original. Lyrics are invented vowel syllables, never the text of a real mantra or prayer, and nothing quotes an existing song or franchise. Music is never needed to play and nothing is graded on it. Every file is listed in `data/audio/LICENSES.md` as generated. All of `data/music/` stays under 8 MB, checked by a test.

- [x] **16.1 Music foundation**
  - Goal: A Music bus with its own volume slider, and a `Music` autoload that plays a `Score` resource: stems started together, each with a level it fades to.
  - Context: Add `Music` to `default_bus_layout.tres` and `GameSettings.volumes`; the board's Sound dialog gains its slider. `Score` (`data/music/*.tres`) holds tempo, tonic, length in bars, and a list of `Stem`s (id, stream, base level in dB). `Music.play(score)` crossfades from the current score over `fade_time`. `Music.set_level(stem_id, db, time)` fades one stem. Like `Sfx`, every play and level change is logged so headless tests can assert on it. Audio starts on the first input on web, as `Sfx` does. `tools/music/generate.py` starts with one placeholder score: a single sine on the tonic.
  - Acceptance: Playing a score starts all its stems on the same frame and logs it. Every stem in a score has the same length in samples, checked for every `Score` in `data/music/`. The Music volume saves and reloads, and mute silences it. `data/music/` is under 8 MB. Every file in it is in `LICENSES.md`.
  - Out of scope: Any real music.
  - Note: `Music` autoload (`scripts/audio/music.gd`) plays a `Score` (`scripts/audio/score.gd`: `id`, `tempo` bpm in 4/4, `tonic` Hz, `bars`, `stems`, `find(id)`) of `Stem`s (`scripts/audio/stem.gd`: `id`, `stream`, `level_db`). `Music.play(score, time)` makes one `AudioStreamPlayer` per stem (`Stem_<id>`, Music bus, Ogg `loop` set in code) in `players`, starts them all in one loop, and fades the old score out over `fade_time` 2 s (with nothing playing, stems start at their levels at once; `play(null)` fades out); `set_level(stem, db, time)` tweens one stem, `level(stem)` reads its target, `SILENT_DB` is -80. `Music.log` entries are `{event: "play"|"level", score, stems or stem/db, time, frame, msec}`. The Music bus is bus 6 in `default_bus_layout.tres` and in `Sfx.BUSES`, so its volume saves in `GameSettings.volumes["Music"]`, the Sound dialog shows a "Music" slider, and Master's mute covers it. `tools/music/generate.py` writes WAV stems to `build/music/`, encodes them with ffmpeg (`-fflags +bitexact`, mono 22050 Hz, `-q:a 2`) to `data/music/<score>_<stem>.ogg`, and writes `data/music/<score>.tres`; the one score so far is `placeholder` (stem `tonic`, a sine on `TONIC` 146.83 Hz, 4 bars at 120 bpm). Music files are listed in `LICENSES.md` as `../music/<file>`. `tests/test_music.gd` reads each stem's sample count from its last Ogg page's granule position and holds `data/music/` under 8 MB.

- [x] **16.2 Instruments and the tonic**
  - Goal: A small set of generated instruments that every score is built from, all tuned to one tonic. The motor hum is retuned to it.
  - Context: In `tools/music/`: a tanpura (Karplus-Strong pluck with a buzzing bridge), a harmonium or shruti-box reed drone, a formant voice that sings vowel syllables (ah, oo, ee, mm), a frame drum and finger cymbals, and the pop kit (kick, clap, synth bass, arpeggio, bright pad, saw lead). The tonic lives in one place, `tools/music/key.py`, and `tools/sfx/generate.py` reads it for `drone_hum`, `lattice_drone`, and `lattice_tone`. A demo score plays each instrument in turn.
  - Acceptance: The generator writes the same files byte for byte on two runs. The demo score's manifest lists every instrument. `drone_hum`, `lattice_drone`, and `lattice_tone` record the tonic (or its fifth) as their base pitch, and the manifest's tonic matches every `Score.tonic`.
  - Out of scope: Arrangements for an act.
  - Note: `tools/music/key.py` holds `TONIC` (146.83 Hz, D3), `FIFTH`, the just-intonation `SCALE` and `hz(degree, octave)` (1-based degrees; 8 is the tonic up an octave). `tools/music/instruments.py` has `INSTRUMENTS` (`tanpura`, `reed`, `voice`, `frame_drum`, `cymbals`, `kick`, `clap`, `bass`, `arp`, `pad`, `lead`), one function per instrument taking `(freq, length, seed)` (the voice also a vowel from `VOWELS` `ah oo ee mm`, shaped by `FORMANTS`), `note(instrument, freq, length, extra, seed)`, and `Track(n, tempo)` whose `add(beat, samples, gain)` wraps tails around the loop. `generate.py` writes the `demo` score (one stem `demo`, one bar per instrument at 120 bpm, `demo_bar`) and `data/music/manifest.json` (`tonic`, `fifth`, `scale`, `instruments`, `vowels`, and `scores.<id>` with `tempo`, `tonic`, `bars`, `stems`; the demo also `instruments: [{bar, instrument}]`); `generate.py --check` renders into `build/music/check/` and fails unless every file matches `data/music/` byte for byte. `tools/sfx/generate.py` imports `key`: `PITCHED` puts `drone_hum` on the tonic (whole cycles per loop via `loop_len`, so DroneSound's pitch 1 is the tonic), `lattice_drone` on the tonic two octaves down and `lattice_tone` on the fifth, and `write_pitches()` records each one's `degree`, `octave` and `hz` in `data/audio/generated/pitches.json`. `tests/test_music_key.gd` runs `--check`, checks the demo against the manifest, finds each tuned sound's energy at its recorded pitch (Goertzel on the WAV), and matches every `Score.tonic` to the manifest.

- [x] **16.3 The mantra**
  - Goal: One original chant hook, 8 bars of syllables and pitches, that every act's score arranges.
  - Context: The hook is data (`tools/music/mantra.json`: syllable, scale degree, length per note), in a call half and an answer half so Act 5 can split it. The generator renders it for any instrument: sung by the formant voice, played by the saw lead, plucked by the tanpura.
  - Acceptance: The mantra uses only invented syllables from the generator's vowel set. Every act score built later names a mantra stem. The hook is exactly 8 bars at every act's tempo.
  - Out of scope: Words, more than one hook.
  - Note: `tools/music/mantra.json` has `call` and `answer`, each a list of `{syllable, degree, beats}` (syllables from `instruments.VOWELS`, degrees for `key.hz`) totalling 16 beats, so the hook is 32 beats, 8 bars at any tempo. In `generate.py`, `load_mantra()` checks it, and `render_mantra(instrument, tempo, half=None, octave=None, seed)` renders it on any instrument (the voice sings the syllables; `MANTRA_OCTAVE` puts the lead an octave up) to exactly `bar_samples(tempo, 8)`, or 4 bars for `half` `"call"` or `"answer"`. Convention for act scores: an `act_*` score must have a stem whose id starts with `mantra` and bars in whole hooks (`MANTRA_BARS` 8); `write_score` asserts both. The `mantra` score (120 bpm, 8 bars) has stems `mantra_voice`, `mantra_lead`, `mantra_tanpura` (files `data/music/mantra_mantra_<instrument>.ogg`), and the manifest gains `mantra: {bars, call_beats, answer_beats}`. `tests/test_mantra.gd` checks the syllables against the manifest's `vowels`, the 16+16 beats and rendered lengths, and every `data/music/act_*.tres` for a `mantra` stem.

- [x] **16.4 Act 1: the home game**
  - Goal: Fully produced mantra pop for the home game: four-on-the-floor kick, synth bass, arpeggio, bright pad, the hook on the saw lead, the tanpura drone underneath.
  - Context: `data/music/act_1.tres`. A `MusicDirector` picks the score from `Career.act()` and sets stem levels from `JobRunner` state: board and briefing play the drone and pad, countdown adds the arpeggio, flying brings in everything, and the results screen drops to the pad again. The intro (11.1) plays this score too.
  - Acceptance: With Act 1 the director plays `act_1`. Each runner state sets the stem levels listed for it. The intro starts the act 1 score.
  - Out of scope: Other acts.
  - Note: `act_1()` in `tools/music/generate.py` writes `data/music/act_1.tres` (120 bpm, 8 bars, one hook, chords `ACT_1_CHORDS` I IV vi I vi I V I) with stems `drone` (tanpura), `pad`, `arp`, `bass`, `kick`, `clap` and `mantra_lead` (files `data/music/act_1_<stem>.ogg`). The `MusicDirector` autoload (`scripts/audio/music_director.gd`, after `Music`) picks the score with `score_for(act)` (`act_<n>.tres` from `Career.act()`, else the nearest earlier act's) and sets a mix: `MIXES` names the stems on in each of `board`, `briefing` (`drone`, `pad`), `countdown` (+ `arp`), `live` (`ALL`, every stem) and `results` (`drone`, `pad`); `STATE_MIX` maps each `JobRunner.State` to one (IDLE board, COMPLETE and FAILED results). Stems a mix names go to their `Stem.level_db` and the rest to `Music.SILENT_DB` (`levels_for(score, mix)`); `play_score(score, mix)` applies levels at once when starting from silence, otherwise fades them; `set_mix(mix, time)`, `play_act(mix)`, and `mix` holds the last one. `JobRunner._ready` calls `MusicDirector.watch(self)` (runners with `pays_out` off, such as cutscene backdrops, are ignored), `JobBoard._ready` calls `MusicDirector.board()`, and `Cutscene.score` (set to `act_1.tres` in `data/story/intro.tres`) is played by `CutscenePlayer` in the `live` mix from the first beat. `tests/test_music_director.gd`.

- [x] **16.5 Act 2: the tryout**
  - Goal: The same hook moves from synths to real instruments: the tanpura and harmonium take over from the pad and arpeggio, a frame drum replaces the clap, and the kick gets lighter.
  - Context: `data/music/act_2.tres`, using the same state levels as 16.4. The recruitment scene (11.2) crossfades from act 1 to act 2 at the bezel drop.
  - Acceptance: With Act 2 the director plays `act_2`, which has no synth stems. The recruitment scene's bezel beat starts the crossfade.
  - Out of scope: Acts 3 to 5.
  - Note: `act_2()` in `tools/music/generate.py` writes `data/music/act_2.tres` (120 bpm, 8 bars, the `ACT_1_CHORDS` again) with stems `drone` (tanpura), `reed` (harmonium chords, the pad's place), `pluck` (tanpura arpeggio, the arpeggio's place), `kick` (one and three, -14 dB against act 1's -8), `frame_drum` (two and four, the clap's place) and `mantra_reed` (the hook on the harmonium, `MANTRA_OCTAVE["reed"]` 1); no bass. `SYNTHS` (`bass`, `arp`, `pad`, `lead`) is in the manifest as `synths`, and `scores.act_2.plays` maps each stem to its instrument (the generator asserts none is a synth). `MusicDirector.MIXES` adds `reed` wherever `pad` is and `pluck` to `countdown`, so the 16.4 state levels hold for both scores. `CutsceneBeat.score` crossfades a score in (every stem, through `MusicDirector.play_score`) when `CutscenePlayer.advance()` reaches that beat; `data/story/recruited.tres` now plays `act_1` from the start (`Cutscene.score`) and sets `act_2` on beat 2, the first without the bezel. `tests/test_music_act2.gd`.

- [x] **16.6 Acts 3 and 4: hand and voice**
  - Goal: Act 3 drops the kick and bass for hand percussion and the sung hook. Act 4 is the same group played faster and rougher, for the act where the governor comes off.
  - Context: `data/music/act_3.tres` and `act_4.tres`; act 4's tempo is higher. Same state levels as 16.4.
  - Acceptance: Each act plays its own score. Neither has synth or kick stems. Act 4's tempo is higher than act 3's.
  - Out of scope: Fleet music.
  - Note: `hand_and_voice(score_id, tempo, rough, seed)` in `tools/music/generate.py` writes both scores (8 bars, `ACT_1_CHORDS`, stems `drone`, `reed`, `pluck`, `frame_drum`, `cymbals` and `mantra_voice`, the hook sung; no kick, no bass; `scores.act_N.plays` in the manifest names each stem's instrument): `act_3()` writes `data/music/act_3.tres` at `ACT_3_TEMPO` 104 bpm, and `act_4()` writes `data/music/act_4.tres` at `ACT_4_TEMPO` 132 with `rough` set (drum in eighths with rim strokes, cymbals every beat, pluck in eighths, every stem through `soft_clip(samples, drive)`). Files are `data/music/act_3_<stem>.ogg` and `act_4_<stem>.ogg`. The director needed no change: its 16.5 `MIXES` already cover `reed` and `pluck`. `tests/test_music_act3_4.gd`.

- [x] **16.7 Act 5: call and response**
  - Goal: Fleet music in kirtan form: one lead voice sings the call half of the mantra, and a choir sings the answer. The choir grows with the fleet.
  - Context: `data/music/act_5.tres` has answer stems baked at three choir sizes (3, 10, and 50 voices: stacked, detuned formant voices). The director crossfades between them by the number of drones under command in `CommandView`. When you drop into one drone to fly it by hand, the lead voice comes forward.
  - Acceptance: With 3, 10, and 50 drones, the matching choir stem is the loudest. Dropping into a drone raises the lead stem. Act 5 plays `act_5`.
  - Out of scope: The Lattice.
  - Note: `act_5()` in `tools/music/generate.py` writes `data/music/act_5.tres` at `ACT_5_TEMPO` 96 bpm, 8 bars, with stems `drone` (tanpura), `reed` (harmonium on tonic and fifth), `frame_drum`, `mantra_lead` (the formant voice singing the call half in bars 1-4, silent after) and `choir_3`, `choir_10`, `choir_50` (the answer half in bars 5-8 by `choirs(tempo, bars, sizes, seed)`: `CHOIR_SIZES` stacked voices, each detuned a few cents with `detune(samples, ratio)`, a few ms late, every third an octave down; each size adds voices to the last). Files are `data/music/act_5_<stem>.ogg`; the manifest's `scores.act_5` has `plays` and `choirs`. No team's preset is Act 5, so `MusicDirector.act_for(job)` (the later of the job's `required_assists` act and `Career.act()`, as `JobBoard.preset_label` shows it) picks a runner's score: the fleet jobs play `act_5`. `CommandView` gains `fleet_changed(count)` (from `add` and `remove`) and calls `MusicDirector.command(self)` in `_ready`; the director keeps it in `fleet` and re-applies the mix on `dropped_in`, `left` and `fleet_changed`. `command_levels(levels, size, forward)` silences every `CHOIRS` stem but `choir_for(fleet_size())` (the nearest size by ratio) and, while `flying()`, raises `LEAD` (`mantra_lead`) by `LEAD_FORWARD_DB` 6. `tests/test_music_act5.gd`.

- [x] **16.8 Tension and weather**
  - Goal: Music that gets out of the way when it should. During a hazard warning or a collapse, every stem falls away except the drone and a pulse, and the full hook returns when it clears. Snow muffles the music the way it muffles the ambience.
  - Context: `HazardZone` warnings and the `HazardScene` collapse set the tension levels. Each score's stems get baked low-passed copies (like `SoundEvent.muffled`) that crossfade in with `WeatherSound.hush`. The muffled copies count against the 8 MB budget.
  - Acceptance: A warning drops every stem except `drone` and `pulse`, and clearing restores them. Full hush plays only the muffled copies. The budget test still passes.
  - Out of scope: Music changing with rain or wind.
  - Note: Every act score has a `pulse` stem (`pulse(tempo, bars, seed)` in `tools/music/generate.py`: two heartbeats a bar on the low frame drum, at `PULSE_DB` -12; `plays` names it `frame_drum`), in the `live` mix with the rest. `write_score` bakes every stem of every score a low-passed copy, `data/music/<score>_<stem>_muffled.ogg` (`muffle(samples)`: the same four-pass `lowpass_loop` as the sfx generator's, normalized with the stem), set as `Stem.muffled`. `Music` starts a `Stem_<id>_muffled` player beside each stem (in `Music.muffled`) on the same frame, and `Music.hush` (0..1) splits each stem's level between the two by equal power, so at 1 only the copies sound; fades now tween the level through `_apply(db, stem)`. `WeatherSound.advance` sets `Music.hush` from its own `hush` and `_exit_tree` lifts it. `MusicDirector.set_tension(source, on)` and `tense()`: while any source holds it, `set_mix` uses the `tension` mix (`drone`, `pulse`) instead of `mix`, and the mix returns when the last lets go (freed sources let go). `HazardZone` holds tension from `warning_started` to `warning_ended` (and lets go in `_exit_tree`); `HazardScene` from each `fire_event` until `calm_after` (5 s) after the last. All of `data/music/` is about 3.9 MB. `tests/test_music_tension.gd`; `tests/test_music.gd` also checks the muffled copies' lengths.

- [x] **16.9 Gates in key**
  - Goal: Race gate sounds play the mantra. Each gate passed sounds the next note of the hook in the act's key, so a clean run plays the melody.
  - Context: `job_gate` (14.4) gains a pitch per gate index taken from `mantra.json`'s scale degrees, through `Sfx.play`'s `pitch`. The countdown beeps sit on the tonic and the fifth.
  - Acceptance: Gate n plays at the pitch of mantra note n (mod length). Countdown pitches are the tonic and fifth.
  - Out of scope: Pitching other cues.
  - Note: `PITCHED` in `tools/sfx/generate.py` now tunes `job_countdown` to the fifth (degree 5, octave 2, 880.98 Hz), `job_go` to the tonic above it (1, 3) and `job_gate` to the tonic (1, 2, 587.32 Hz, a short scoop into a held blip); all three are recorded in `data/audio/generated/pitches.json` and checked at their pitch by `tests/test_music_key.gd`'s `TUNED`. `SoundEvent.pitches` (a `PackedFloat32Array` of pitch scales stepped through in turn) holds on `job_gate` in `data/audio/bank.tres` the 22 notes of `mantra.json` (call then answer) as ratios over the tonic, and its `pitch_variance` is now 0. `JobCues.gates` counts gates the flown drone passed this run (reset on BRIEFING) and `JobCues.gate_pitch(n)` returns `pitches[n mod size]`, passed as `Sfx.play`'s `pitch`. `tests/test_gates_in_key.gd`.

- [x] **16.10 Crew motifs**
  - Goal: Each crew member has a voice in the score. If they die, it is gone from the music for good.
  - Context: `Character.motif` (data) names a stem id, such as Bea's harmonium line or Dot's frame drum fill. Act scores include those stems, and the director plays a motif only while `Roster.status` is active; injured plays it quieter. Rule 7 holds: nothing brings a dead character's motif back.
  - Acceptance: Every motif named in `data/characters/` exists in the act scores that use it. A dead character's motif stays silent in every later score and after a save and reload. An injured character's motif plays below its base level.
  - Out of scope: Motifs for pilots who are not crew.
  - Note: `Character.motif` (a stem id; `validate()` allows one only for crew, `can_be_harmed`) is `motif_bea` (harmonium line), `motif_dot` (frame drum fill), `motif_marlo` (high tanpura pluck) and `motif_ozzie` (hummed "mm" voice) in `data/characters/`. In `tools/music/generate.py`, `MOTIFS` maps each stem to its instrument, `motifs(tempo, bars, seed)` renders them once per half of the hook, and `add_motifs(...)` appends them at `MOTIF_DB` -13 to every score in `MOTIF_ACTS` (`act_2` to `act_5`), whose manifest entries gain `motifs` and `plays` for each (files `data/music/act_N_motif_<name>.ogg` and `_muffled.ogg`, in `LICENSES.md`; all of `data/music/` is about 4.9 MB). `MusicDirector.crew_levels(levels)` runs in `set_mix` after `command_levels`: a motif sounds as its mix sets it while `Roster.status` is ACTIVE, `INJURED_DB` 9 lower while INJURED, and at `Music.SILENT_DB` once DEAD; the director re-applies the mix on `Roster.status_changed`. Motifs are in the `live` mix only (the 16.4 mixes name none). `tests/test_crew_motifs.gd`; the act 2 to 4 tests' `STEMS` gain the motifs.

- [x] **16.11 The Lattice**
  - Goal: The Lattice sings: a dense choir of the mantra from thousands of captured machines. Each reclaimed unit thins it, at the override port only one voice is left, and when it switches off the music stops.
  - Context: `data/music/lattice.tres` has choir stems at four densities over the tonic drone, in tune with `lattice_drone`. The director fades the densities by the fraction of units reclaimed (`LatticeFight.unit_reclaimed`), holds a single voice during `OverrideHold`, and on `boss_disabled` fades to silence. No explosion stinger, no victory fanfare. When `data/boss/lattice.tres` has `enabled` false, the score is never loaded.
  - Acceptance: Density levels follow the reclaimed fraction. During the override hold only `voice` and `drone` play. After `boss_disabled` no music stem plays. With the boss disabled, the score is never loaded.
  - Out of scope: An ending credits theme.
  - Note: `lattice()` in `tools/music/generate.py` writes `data/music/lattice.tres` at `LATTICE_TEMPO` 80 bpm, 8 bars, with stems `drone` (sines on `LATTICE_DRONE`, the tonic two octaves down as `lattice_drone`, plus the octave above), `voice` (the whole hook sung by one formant voice) and `density_1` to `density_4` (`lattice_choirs(tempo, bars, seed)`: `LATTICE_BASE` 12 detuned voices, each denser one the last stacked `LATTICE_STACK` 8 times at its own delay and gain, so 12, 96, 768 and 6144 voices); files `data/music/lattice_<stem>.ogg` and `_muffled.ogg`, in `LICENSES.md`, and the manifest's `scores.lattice` has `plays`, `densities` (voices per stem) and `drone` (`degree`, `octave`, `hz`, matched to `pitches.json`). All of `data/music/` is about 5.8 MB. `LatticeFight._ready` calls `MusicDirector.lattice(fight)`, which keeps it in `boss_fight` and re-applies the mix on `unit_reclaimed`, `phase_started`, `fleet_drone_lost` (deferred, after the unit goes back) and `boss_disabled` (sets `boss_off`). A runner the fight belongs to plays `lattice_score()` (`LATTICE_PATH`; null, never loaded, unless `BossGate.listed()`; each load is recorded in `BossGate.loads`) instead of an act score. `set_mix` ends with `boss_levels(levels, fraction, hold, off)`: `DENSITIES` (densest first) crossfade by equal power on `reclaimed_fraction()` (reclaimed over `Boss.gap_units`), while `holding()` (phase OVERRIDE) only `HOLD` (`drone`, `voice`) sound, and once off every stem is at `Music.SILENT_DB`, results screen included; scores without the densities pass through. `tests/test_music_lattice.gd`.

## Epic 17: Arcade front end and crew radio

Done when the game opens like an arcade cabinet instead of a spreadsheet, the crew have faces that emote and talk, and the crew talk to you while you fly, in jobs and in free flight. The front end tells the tryout story: in Act 1 it is a home arcade game (PRESS START, big job cards, high scores); from Act 2 the same layout becomes the team's ops console. Faces stay drawn in code (a face rig with expressions, blinking, and a mouth that moves while talking), so they stay consistent, cheap on the web build, and readable at 64 px; a character's `portrait` texture still overrides them. UI and dialogue only: nothing here touches the flight model, assists, or grading (rules 1, 2, 8), and nothing is graded on what the crew say. Characters stay data (rule 6): no scene names a character, and the dead never speak. Every screen works with keyboard, mouse, and gamepad. Lines are original, and nothing imitates an existing franchise's menus, comms, or characters.

Order: faces first (17.1, 17.2), since the board and the radio both use them; then the front end (17.3 to 17.6); then the radio (17.7 to 17.10).

- [x] **17.1 Face rig**
  - Goal: `CharacterPortrait` draws a real face: brows, eyelids, pupils, and a mouth, with six expressions (neutral, happy, determined, worried, shocked, sad), blinking, and a `talking` flag that moves the mouth.
  - Context: Same shape language as now (round body, big eyes, one silhouette feature per character, colors from the `Character`). A pure `pose(expression, t)` returns the face parameters (brow angle and height, lid openness, pupil offset, mouth width, curve, and openness) so tests check the face without reading pixels. Blinks come from a seeded timer, so tests reproduce. Talking opens and closes the mouth on a rhythm. The dead stay greyed, with eyes closed. Everywhere a portrait already shows (board, pilot select, HUD, results) gets the new face for free.
  - Acceptance: Every expression gives a distinct pose; happy curves the mouth up, sad curves it down, shocked opens it wide. A blink closes the lids for 0.1 to 0.2 s every 2 to 6 s, at the same times for the same seed. While talking, mouth openness changes over time; when not talking, it holds the expression's value. A `portrait` texture still overrides the drawn face. Every character draws without errors at 32, 64, and 128 px. A dead character's lids are closed.
  - Out of scope: Lip sync to audio, head turns, new characters.

- [x] **17.2 Talking faces**
  - Goal: Lines carry an expression, and the HUD line box shows the speaker's face making it and talking while the text types out.
  - Context: `data/dialogue/*.json` entries may be a string (as now) or `{"text": ..., "face": ...}`; existing files stay valid. Without a `face`, each event has a default: briefing determined, gate_passed happy, warning shocked, strike sad, complete happy, fail sad. `BarkBox` types the text at a steady rate, with the portrait talking until the last character and then holding the expression. The chirp from 14.8 plays as now. Results-screen lines show the face too.
  - Acceptance: A string line and an object line both load, and the object's `face` is used. A line with no `face` gets its event's default expression. While the text is typing, the portrait is talking; once the full line shows, it is not. The full line shows within 2 s of a 40-character line starting. Every existing bark test passes unchanged.
  - Out of scope: New events (17.8), the radio panel layout (17.7).

- [x] **17.3 Title screen**
  - Goal: After the intro (or straight away once it has been seen), a title screen: the game's name, PRESS START (any key, click, or gamepad button), the best score, and the city slowly orbiting behind it.
  - Context: The backdrop reuses the cutscene backdrop system from 11.1 with the sandbox scene and an orbit camera, HUDs hidden. The best score is the player's highest single job payout, read from the save; zero shows as dashes. Start opens the job board (or pilot select on a new game, as now). Esc on the board returns here.
  - Acceptance: Launching with `intro_seen` set opens the title screen, not the board. Any key, a mouse click, or a gamepad button opens the board; with no pilot chosen, it opens pilot select first. The best score matches the save. The backdrop loads with no errors and its camera orbits. Esc on the board returns to the title.
  - Out of scope: Attract-mode demo flights, an options screen (17.5).

- [x] **17.4 Job carousel**
  - Goal: The job board shows one big card at a time, which you flip through with left and right (keys, d-pad, or the on-screen arrows), with a row of dots for position, and Enter (or click) flies it.
  - Context: A card shows the job's title, client, type icon, pay, act assists, best grade so far, and the crew member on comms for it, with a one-line pitch in their voice (a new `pitch` event; three lines per crew member, per the bark rules). A locked card shows a padlock and one short reason ("Join City Rescue Air"); the full reason is in a tooltip. START HERE and the boss row keep their behavior. The carousel opens on START HERE, or on the last job flown. Story 5.3's rules are unchanged: every test in `tests/test_job_board.gd` keeps passing, with only its node lookups updated.
  - Acceptance: Right moves to the next card and wraps at the end; left does the reverse; the dots mark the current card. Enter on an unlocked card opens its job scene; on a locked card it does nothing and shakes the card. A locked card shows one short reason. The card's comms face belongs to a living crew member in that job's field or on its comms. The carousel opens on START HERE for a new career. Every existing job board acceptance still holds.
  - Out of scope: Job art beyond a type icon, sorting and filtering.

- [x] **17.5 Menu and navigation**
  - Goal: The six small footer buttons become one arcade menu (FLY, FREE FLIGHT, GARAGE, PILOT, CREW, OPTIONS), and the crew roster moves to its own CREW page with big faces.
  - Context: Up and down move between menu items, left and right move within the carousel, Enter selects, Esc goes back; mouse and gamepad do the same. The focused item is always visible. GARAGE is the shop, OPTIONS holds Sound, Quality, and Watch intro, and CREW shows each crew member's face, role, status, and memorial line (taking over what the board's crew panel shows now). Offers from teams still ask on the board. Wallet, reputation, team, and act stay in the header.
  - Acceptance: Every action the old footer offered is reachable from the menu by keyboard alone. Focus never lands on a hidden or disabled control. At 960×720 and 1920×1080 no control or label is clipped and nothing needs scrolling except the CREW page. The CREW page shows every roster member, with the dead greyed and memorial lines shown. Esc from any page returns to the menu, and from the menu to the title.
  - Out of scope: Rebinding keys, new options.

- [x] **17.6 Cabinet and ops skins**
  - Goal: The front end wears an arcade cabinet skin in Act 1 and the team's ops console skin from Act 2 on, and the switch happens during the recruitment scene.
  - Context: A skin is a resource (colors, fonts, panel style, sounds) applied to the title, board, menu, and CREW page. Cabinet: chunky display type, scanlines, a coin chime on Start, and the bezel colors from 3.5. Ops: the thin-line look of the flight HUD (9.5) in the current team's colors. A display font may be added under `data/ui/fonts/` only with an open font license, listed beside it. The recruitment scene (11.2) already has "the bezel falls away"; the next screen after it uses the ops skin.
  - Acceptance: With `Career.act()` at 1, every front-end screen uses the cabinet skin; at 2 or more, the ops skin with the current team's colors. Accepting the first team offer and finishing the recruitment scene shows the board in the ops skin. Scanlines and the coin chime appear only in the cabinet skin. Any added font has its license file next to it.
  - Out of scope: Per-team skins beyond colors, animated transitions between skins.

- [x] **17.7 Radio panel**
  - Goal: The HUD line box becomes a crew radio: a larger talking face, the speaker's name and role, a short burst of static when a line opens, and a queue so lines never talk over each other.
  - Context: Builds on 17.2. Lines have a priority: warning and strike preempt anything; other events wait their turn, and chatter older than 4 s is dropped instead of played late. At most one chatter line per 6 s, configurable on the panel. The static burst is a generated sound under the Epic 14 rules. The panel sits low on the left, clear of the radar, the objectives panel, and the race HUD.
  - Acceptance: A warning raised while a chatter line is showing replaces it at once. Two chatter lines raised together play one after the other, never at the same time. A chatter line queued for over 4 s is dropped. No two chatter lines start within the configured gap. The panel does not overlap the radar, objectives, or race HUD at 960×720 or 1920×1080. Every existing bark test passes.
  - Out of scope: Voice audio, player replies.

- [x] **17.8 Flight events**
  - Goal: A `FlightWatcher` node turns what the drone is doing into crew events: takeoff, near miss, low pass, top speed, battery low, crash, reset, weather change, and long hover.
  - Context: It reads the drone, the ground height, and the weather, and never writes to them (rules 1 and 2). Thresholds live in a resource (`data/radio/flight_events.tres`), for example near miss as passing within 2 m of static geometry above 8 m/s without contact, low pass as under 3 m above ground above 10 m/s, battery low at 25 percent, and long hover as 20 s still. Each event has its own cooldown so a long low pass is one event, not one per frame. Jobs and the sandbox both place one. Nothing is graded on these events.
  - Acceptance: Each event fires from a scripted drone state that meets its threshold and does not fire from one just short of it. Each respects its cooldown. Battery low fires once per charge. Crash fires on contact above the crash speed, not on a gentle landing. The watcher changes no drone, intent, or assist value (checked before and after a run).
  - Out of scope: Lines for these events (17.9), scoring style or tricks.

- [x] **17.9 Flight lines**
  - Goal: Every crew member reacts to the flight events in their own voice.
  - Context: The new events join `Bark.EVENTS`, so the bark rules apply: at least three lines per crew member per event, injured variants for anyone who can be harmed, the dead never speak, no repeats within a job unless only one line exists. Each line sets a `face`. `speaks_on` decides who reacts to what (Marlo calls near misses, Dot winces at crashes and low battery, Rin comments on top speed). Voices follow `docs/CHARACTERS.md`.
  - Acceptance: `test_every_member_has_three_lines_per_event` passes with the new events included. Every new line has a valid `face`. In a scripted near miss on a job with Marlo on comms, Marlo's radio line plays. With Marlo dead, no near-miss line comes from Marlo.
  - Out of scope: Branching conversations.

- [x] **17.10 Free-flight companion**
  - Goal: In free flight one crew member rides along on the radio: they greet you at spawn, react to your flying, and when things go quiet they suggest something to try in the city.
  - Context: The companion is data on the sandbox (a list in order of preference); the first living one rides along, so a death changes who you hear. Suggestions are data (`data/radio/suggestions.tres`): a line, plus a `MapMarker` kind or landmark it points at (a rooftop pad, the plaza, downtown, the jammer). When one plays, the radar lights its target until you reach it or another suggestion plays. Reaching it gets a short reaction line. A suggestion plays after 45 s without a line, never during the first 10 s, and never twice in a row.
  - Acceptance: Free flight greets with the first living companion within 3 s of spawn. With them dead, the next one in the list greets instead. After 45 s with no line, a suggestion plays and the radar lights its target. Reaching the target plays a reaction and clears the highlight. No suggestion plays during a job. Nothing is graded or saved from free flight.
  - Out of scope: Free-flight missions with rewards, multiple companions talking to each other.
- [x] **17.11 The board explains itself**
  - Goal: A first-time player can tell what the job board is for and what to press, in bigger, arcade-style type.
  - Context: Playtest: the board after PRESS START did not feel intuitive. `Job.summary` is one plain sentence on what you do, shown on the card under the title. One line under the header says what the board is for; a hint under the menu says what the focused item does; the controls run along the bottom; "JOB 2 OF 9" sits beside the dots. The cabinet skin's display font is Press Start 2P (SIL OFL 1.1, `data/ui/fonts/` with `OFL.txt` and a README listing it). Type sizes go up on the card, menu, and header in both skins.
  - Acceptance: Every board job has a summary and its card shows it. The how-to line and the controls are on screen. The menu hint follows focus and every menu item has one. The counter tracks the card and wraps. The cabinet's display font is the arcade font with its licence beside it. The longest card fits at 960×720.
  - Out of scope: The Lattice's card text, skinning the dialogs, the radio font (18.12).
- [x] **17.12 Story crawl**
  - Goal: The title says why you are playing: a story crawl rolls up from PRESS START and away towards the logo, over the city.
  - Context: The story is data (`data/ui/crawl.tres`: text, start delay, speed, loop pause), drawn from VISION.md: pilots are stars, the teams hide tryouts in a home racing game, a scout is watching, the crew are at stake. Its wording is original. The text is set flat in a SubViewport and drawn on a plane tipped away from the viewer by a canvas shader, fading out in the distance and rising out of nothing at the bottom. It uses the skin's display font and accent, loops, and never takes input.
  - Acceptance: The crawl sits between the logo and PRESS START and ignores the mouse. Its text names the tryout, the scout, and the crew, and ends on "THIS IS DRONE SPORTS". It rises over time and starts over after the last line leaves. Any key mid-crawl still opens the board.
  - Out of scope: Narration, music cues, skipping the intro.
- [x] **17.13 Main title theme**
  - Goal: The title and the job board have their own theme music: an original heroic space-opera march, brass over strings, timpani, and snare.
  - Context: Generated like every score (Epic 16 rules: stdlib, fixed seeds, baked Ogg stems, in the one key, original, quoting nothing). New instruments in `tools/music/instruments.py`: `brass`, `strings`, `timpani`, `snare`. `generate.py`'s `theme()` builds 26 bars at 104 bpm: a tutti intro hit, the mantra's call recast as a trumpet fanfare, its answer on the strings over horns, then the call with the full band, rolling round to the hit. Two stems, `orchestra` and `drums`. `MusicDirector.title()` plays it with every stem; the title screen and the board call it, so the theme carries from one to the other. `board()` (the act score's board mix) stays for jobs.
  - Acceptance: `data/music/theme.tres` has the two stems and is in the manifest, in the key, marked as built from the mantra's call and answer. `title()` plays every stem at its level. Opening the title then the board plays the theme once, in Act 1 and Act 2. A job still plays its act's score. `data/music/` stays under 8 MB and every new file is in `LICENSES.md`.
  - Out of scope: A different theme per act, a results-screen fanfare.

## Epic 18: A friendlier crew

Done when the crew are characters you want to see: Saturday-morning-cartoon faces (bold outlines, flat bright colour, big expressive eyes, exaggerated poses, squash and stretch), warm lines that cheer you on, happy chirps, and faces on their drones. The style is original: no character, design, or catchphrase imitates an existing cartoon or franchise. The existing lines stay; warmer ones are added on top, and the new voice is on your side (encouraging, comforting, a little goofy). Serious moments stay sincere: hazard warnings, strikes, injuries, deaths, memorials, and the Lattice never get emotes, gags, or jokes, and the dead never speak or appear on a drone. Faces stay drawn in code from `Character` data (rule 6) and readable at 32 px. Nothing here touches the flight model, assists, or grading (rules 1, 2, 8); drone faces are visual only. Order: 18.1 first (every later story uses the new face), then 18.2 to 18.6 in any order, then 18.7.

- [x] **18.1 Cartoon faces**
  - Goal: `CharacterPortrait` redrawn in a Saturday-morning-cartoon style: a thick dark outline, big eyes set low and wide with two shine dots, short brows that sit high and only move for big emotions, a small mouth on the face itself (no snout patch), cheek blush, and a soft smile as the resting face.
  - Context: `scripts/ui/character_portrait.gd` from 17.1. Keep `pose(expression, t)` and its fields, adding `eye_scale`, `squint`, and `blush`; keep the six expressions, the seeded blink, and talking. Each character's silhouette feature (`shape`) is kept but redrawn chunkier. `neutral` becomes a soft smile; `determined` reads as eager, not angry. The dead stay greyed with eyes closed and no blush or shine.
  - Acceptance: Every expression still gives a distinct pose; happy curves the mouth up, sad down, shocked opens it wide. In every expression but determined the brows' inner ends are not lower than their outer ends. Eye height is at least 22% of the face in every pose with lids open. Neutral's mouth curves up. Blinks and talking still behave as 17.1's tests require. Every character draws without errors at 32, 64, and 128 px. A dead face has closed lids, no blush, and no shine.
  - Out of scope: Body motion (18.2), emotes (18.3).
  - Note: `CharacterPortrait.pose()` now also returns `eye_scale`, `squint` and `blush`; `CharacterPortrait.EYE` (eye half-size per head radius) and the static `eye_height(p)` give the open eye's share of the face, and `shows_shine()` is false for the dead or shut-eyed. The head is a circle of radius 0.34 of the control's size centred 0.08 below middle, eyes at (+/-0.4, +0.08) of that radius; `_draw_feature` draws silhouette features behind the head and `_draw_headwear` draws hats, goggles and visor in front, all with an ink outline of max(0.1 r, 1.2 px). Headwear sits with its lowest edge at `HEADWEAR_BOTTOM` and the static `brow_top(p)` keeps every brow below it. A dead face ignores its expression: shut lids, level brows, a flat closed mouth. 18.2's motion should transform the whole draw (e.g. `draw_set_transform`) rather than move parts, and 18.7 can mirror the pose fields directly.

- [x] **18.2 Squash and stretch**
  - Goal: Faces that move like cartoons: an idle bob, squash and stretch while talking, a pop-up of the eyes when shocked, a droop when sad, a hop when you pick someone, and eyes that follow the cursor on the board.
  - Context: A pure `CharacterPortrait.motion(expression, t, talking)` returns scale and offset, so tests read motion, not pixels. Each character's bob has its own phase and speed (data on `Character`, e.g. `bounce`), so the crew do not move in unison. Pilot select and the board call `hop()` on a pick; `look_at(point)` aims the pupils within the eye.
  - Acceptance: Idle motion stays within 6% of the face's size and repeats with the same phase. While talking the face squashes and stretches, holding its area within 5%. `hop()` returns the face to rest within 0.6 s. Pupils follow a point and never leave the eye. A dead face does not move.
  - Out of scope: Full-body characters, arms.
  - Note: The pure static `CharacterPortrait.motion(expr, t, talking, bounce, hop_age, expr_age)` returns `scale` (area-preserving, pivoted at the bottom of the head), `offset` (per face size) and `eye_pop`; `_draw` applies it with one `draw_set_transform`, `current_motion()` is `still()` for the dead, and `current_pose()` folds in `look` and the eye pop. Each character's rhythm is `Character.bounce` (bobs per second, phase), `hop()` lasts `HOP_TIME` 0.45 s, and `look_at(global_point)` or `follow_mouse` aims the pupils, clamped by `pupil_center()`; the board's comms and crew faces follow the mouse and hop on a carousel move or click, pilot cards hop on hover or focus. 18.3 can anchor emotes to the moved face via `current_motion()`, and 18.7 can mirror `motion()` on the drone panel.

- [x] **18.3 Emotes**
  - Goal: Little cartoon emotes by the face: hearts on a clean finish, sparkles on a best time, a sweat drop when worried, a "!" on a near miss, music notes when idle and happy, stars when dizzy after a crash.
  - Context: Emotes are data (`data/crew/emotes.tres`: an event or expression mapped to an emote, its time, and its drawing); drawn in code beside any `CharacterPortrait`. One emote at a time, the newest replacing the oldest.
  - Acceptance: Each mapped event shows its emote for its time, then clears. Hazard warnings, strikes, injuries, deaths, memorials, and every Lattice line show no emote. A dead character never shows one.
  - Out of scope: Emotes in the 3D world (18.7 has its own faces).
  - Note: `data/crew/emotes.tres` is an `EmoteTable` of `Emote`s (key: an event or expression; drawing, time, colour, and `idle` to wait until the face stops talking), plus `quiet_events` (warning, strike, hurt, memorial, epilogue) and `quiet_job_types` (boss); `EmoteTable.for_line(event, face, job_type)` picks event first, then face. `EmoteBubble.attach(portrait)` draws one emote at a time as the portrait's child, riding `current_motion()`, and clears for the dead; `BarkBox.emote` plays each opened line (complete with no strikes becomes `clean_finish`, anything after a casualty stays quiet) and the results closing line uses `Results.emote_event(r)` (`best` from the new `JobResult.new_best`, else `clean_finish`). 18.5's new events get emotes by adding table entries, and 18.7 should reuse the same keys for its drone panel.

- [x] **18.4 Warmer lines**
  - Goal: More lines for every character and every event, in a voice that is on your side: cheering you on, celebrating with you, laughing off a crash, and comforting you after a fail. Each character keeps their personality and gets their own names for you (`Character.calls_you`, e.g. "ace", "boss", "buddy").
  - Context: Added to the existing `data/dialogue/*.json` pools (object lines with a `face`); nothing existing is removed or reworded. Lines may use `{you}`, filled from the speaker's `calls_you`. Warning, strike, injury, and memorial lines added here are sincere and kind, never jokes. Lines are original.
  - Acceptance: Every living character's pool grows by at least three lines for every event they speak on. Every `{you}` resolves and no line shows a raw brace. Every existing line is still present. No added line in warning, strike, injury, or memorial pools uses an exclamation of delight or an emote word (checked against a word list). Every existing bark test passes unchanged.
  - Out of scope: New events (18.5), voice acting.
  - Note: Every dialogue pool (all but `trench`, `epilogue`, and the `memorial` string) has three more lines per status; new lines are `{text, face}` objects, except in `warning`, `strike`, and `hurt`, which take plain strings with no `{you}` so their face stays the event default and raw-text tests still match. `Character.calls_you` (validated non-empty) fills `{you}` via `Bark.fill(c, text)`, picked by the line's hash so a line always reads the same; `Bark.pool` and `face_of` work on filled text, so anything reading `lines_of` directly gets raw `{you}`. `tests/lines_before_18_4.json` is the pre-18.4 baseline `test_warmer_lines.gd` compares against; 18.5's new events need `{you}`-safe lines and a `calls_you` already exists for every character.

- [x] **18.5 Little moments**
  - Goal: The crew notice you: a hello when you come back to the board, a cheer after a run of clean gates, encouragement when you retry a job you just failed, celebration when you buy an upgrade or unlock a job, and a wave goodbye when you quit.
  - Context: New events in `Bark.EVENTS` (`hello`, `streak`, `retry`, `unlock`, `goodbye`), each with default faces and emotes, lines in every character's file, and a cooldown so the same character does not greet you twice in a minute. They speak through the existing bark and radio paths.
  - Acceptance: Each new event plays a line from a living crew member when it happens and never from the dead. A streak fires after the set number of clean gates, once per streak. Retry fires only on relaunching the job just failed. Cooldowns hold.
  - Out of scope: Relationships or affinity scores.
  - Note: `Bark.MOMENTS` (`hello`, `streak`, `retry`, `unlock`, `goodbye`) are in `Bark.EVENTS` with default faces, emotes in `data/crew/emotes.tres`, and lines in every character file; `Bark.moment(event)` lets any living crew member but the player's pilot say one (never on a boss job), each character at most once per moment per `MOMENT_COOLDOWN` (60 s, static `Bark.moment_times`). The board owns a `bark` and a `radio` BarkBox for the hello (skipped right after a death), an upgrade, or a newly flyable job, and Esc sets `TitleScreen.wave_goodbye` so the title says goodbye on its own radio; in a job `Bark.streak` cheers once at `streak_gates` (5) clean gates (reset by crash, reset, or strike) and `Bark.last_failed` adds a retry to the next briefing of the same job unless someone was hurt. 18.7 can reuse the moment keys and emotes for drone-face reactions.

- [x] **18.6 Happy chirps**
  - Goal: Chirps that sound friendly: a rising two-note chirp for happy lines, a little giggle trill for celebrating, a wobble for worried, and a soft falling "awoo" for sad, each pitched per character.
  - Context: Generated by `tools/sfx/generate.py` on the scale in `tools/music/key.py` (16.2), so they sit in the music's key; `Bark` picks the chirp from the line's face and pitches it by `chirp_pitch`. Strike, injury, and memorial lines keep the plain chirp.
  - Acceptance: Each face plays its chirp variant. Every chirp's base pitch is a scale degree from `key.py`. The generator stays byte-for-byte deterministic. Every file is in `LICENSES.md`.
  - Out of scope: Voice acting, sung lines.
  - Note: `tools/sfx/generate.py` makes `crew_chirp` (now on the key) plus `crew_chirp_happy`, `_celebrate`, `_worried` and `_sad`, all starting on the tonic two octaves up (`PITCHED`, so in `pitches.json`), and `--check` re-renders into `build/sfx/check/` and fails on any byte difference. `Bark.chirp(id, face, event)` plays `Bark.chirp_for(face, event)`: `CHIRPS` maps each face (determined shares happy, shocked shares worried), a happy or determined line on a `CELEBRATE_EVENTS` event (`complete` only; 18.5 should add `unlock` and `streak`) giggles, and `PLAIN_EVENTS` (`warning`, `strike`, `hurt`, `memorial`) stay plain; every `Character.chirp_pitch` is now a scale ratio (octave-reduced) so pitched chirps stay in key, which `tests/test_happy_chirps.gd` checks, and tests that count chirps should match any id starting `crew_chirp`.

- [x] **18.7 Drone faces**
  - Goal: A crew member's drone wears their face: a small LED face panel on the front of the drone, in their colours, that blinks, reacts to what happens (happy through a gate, shocked on a near miss, dizzy after a crash), and looks the way they are heading.
  - Context: A `DroneFace` child of `DroneLook`, shown only on drones a living crew member flies (`CommandView.pilots`, the relay, the Lattice's returned drones); the player's own drone stays faceless. Drawn by a cheap unshaded shader on a quad, driven by the same `CharacterPortrait.pose()` values, so it matches the portrait. Reactions come from 17.8's flight events for that drone. Visual only: no mass, collision, or flight value changes.
  - Acceptance: A crew-flown drone shows its pilot's face; the player's drone and unpiloted drones show none. The panel's pose matches `pose()` for the same expression and time. Each mapped flight event changes its expression, then it returns to rest. The drone's mass, collision shapes, and flight values are unchanged with a face on. It compiles and draws under GL Compatibility.
  - Out of scope: Faces on AI racers or the Lattice's units.
  - Note: `DroneFace.wear(drone, character)` puts a `Look/Face` quad (shader `scenes/drone/drone_face.gdshader`, one uniform per `CharacterPortrait.pose()` field plus `squash`/`bob` from `motion()`) on a drone; `FleetCrew` and `CommandView.add(d, pilot)` call it, so fleet, relay and the Lattice's returned drones wear faces and the player's or freed drones do not, and `DroneFace.of(d)` finds it. Each face owns a `FlightWatcher` on its drone and maps events through `DroneFace.REACTIONS` (plus `gate` from `Relay._on_gate`) to an expression held for a time, then `REST`; `hold(expr, seconds)` shows any expression, and a dead pilot's panel hides and never reacts. New reactions are one `REACTIONS` entry; the panel blinks with the portrait's seed, so both faces blink together.

- [x] **18.8 Babble voices**
  - Goal: Every crew member talks in their own babble: a short looping gibberish voice that runs while their line types out and stops when it finishes. Pitch, speed, and timbre carry personality (a quick high chatter, a slow low rumble).
  - Context: Generated offline from 16.2's formant voice (vowel syllables, never real words), one loop per character from data on `Character` (`babble_pitch`, `babble_rate`, `babble_vowels`), under the Epic 14 sample-only rules and on the music's scale. `BarkBox` and the radio panel start it with the typing and stop it on the last character; 18.6's chirp still opens the line. Serious lines (warning, strike, injury) babble slower and lower; memorials and the dead are silent.
  - Acceptance: A line's babble plays while it types and stops within 0.1 s of the last character. Each character's babble differs in pitch or rate from every other's. A skipped or replaced line stops its babble. The dead never babble. The generator stays deterministic and every file is in `LICENSES.md`.
  - Out of scope: Real speech, lip sync to audio.
  - Note: `Character.babble_pitch` (a scale ratio on the tonic an octave up), `babble_rate` (syllables/s) and `babble_vowels` (of `Character.VOWELS`) are read straight from `data/characters/*.tres` by `tools/sfx/generate.py`, which bakes `babble_<id>.wav` (`BABBLE_SYLLABLES` 12 formant-voice syllables via the new `instruments.formant_table`, smpl loop) for every character; each is a `babble_<id>` event on the Voice bus (`Character.babble_event()`), so a new character needs the three fields, a bank entry and a `LICENSES.md` row. `Bark.babble_for(id, event)` gives {event, pitch} (`SERIOUS_BABBLE` warning/strike/hurt at `SERIOUS_BABBLE_PITCH` 0.75, {} for memorials and the dead), and `BarkBox` loops it on its own `voice` player via the new `Sfx.play_on(player, id, pitch)` after the chirp, stopping it in `_type()` on the last character, on `skip()` (not bound to any input yet) or when `_open` replaces the line; `BarkBox.babbling` holds the running event. 18.9's cue should play before `_open`'s chirp and babble, and must not stop `voice`.

- [x] **18.9 Incoming call**
  - Goal: You always know someone is about to talk: a short chime plays just before the radio panel opens, and the face pops in cartoon-style (scale overshoot and settle) instead of appearing. Urgent lines (warning, strike) use a sharper alert tone.
  - Context: The 17.7 radio panel, its queue, and its static burst. Chime and alert are generated sounds on the UI bus. The pop-in uses 18.2's motion.
  - Acceptance: Every line opening the panel plays its cue first: the alert for warnings and strikes, the chime otherwise. The face reaches rest within 0.4 s of opening. A line that replaces the current one replays the cue. Every existing radio test passes.
  - Out of scope: Player replies.
  - Note: `BarkBox._open` plays `BarkBox.cue_for(event)` (`radio_alert` for `ALERT_EVENTS` warning and strike, else `radio_chime`; generated, on the key, UI bus) before the static, chirp and babble on every line that opens the panel, including replacements and queued lines when they open, and never touches the `voice` player, so 18.8's babble runs as before. `CharacterPortrait.pop_in()` feeds a new trailing `pop_age` argument of `motion()` that grows the face from `POP_IN_FROM` 0.3 with an overshoot to exact rest at `POP_IN_TIME` 0.32 s. With the user's approval, `test_line_opens_with_static_chirp_face_and_role` now expects the cue, then `radio_static`, then the chirp; no other existing test changed.

- [x] **18.10 Distress and signal lost**
  - Goal: When a crew member's drone is in trouble (battery low, a near miss, a crash, close to a hazard), their face shows distress: a wince, a sweat drop, a shake, with a repeating alarm while it lasts. When their drone goes down, their portrait fills with animated TV static and SIGNAL LOST until it is back in the air.
  - Context: A new `distress` expression on `CharacterPortrait`, driven by 17.8's flight events for that crew member's drone. The static overlay is drawn in code on the portrait. A drone going down is not a death: the dead keep their greyed, quiet portrait from 17.1 and never get static, distress, or alarms.
  - Acceptance: Each trouble event shows distress and starts the alarm; it stops when the trouble ends. A downed drone shows static until it flies again, then the face returns. The alarm never plays for the player's own drone or for the dead. The flight model, assists, and grading are untouched.
  - Out of scope: New ways for crew to be harmed (rule 7 is unchanged).
  - Note: `CrewDistress.watch(face, drone, runner)` (a child of the portrait, made by `CommandView`'s overlay for every piloted drone) listens to the drone's `DroneFace` watcher (or its own `FlightWatcher`): `TROUBLE` events (battery low, near miss, crash) and being within `HAZARD_MARGIN` of a runner's `HazardZone` set `CharacterPortrait.DISTRESS` (a pose plus a shake in `motion()`, deliberately not in `EXPRESSIONS`, so line faces and their tests are unchanged), a `distress` sweat-drop emote (not near a hazard or on a boss job), and the generated `crew_alarm` every `ALARM_GAP` while it lasts. A crash sets `down`, so `portrait.signal_lost` draws TV static and SIGNAL LOST until the drone is upright above takeoff height for `UP_TIME` or resets; the dead and a drone flown through `PilotInput` never get static, distress or the alarm.

- [x] **18.11 Flying with personality**
  - Goal: You can tell who is who by how they fly: one bold flyer cuts corners and pulls ahead, one steady flyer holds formation and radios advice, one eager but clumsy flyer wobbles and drifts wide, each true to `docs/CHARACTERS.md`.
  - Context: A `FlightStyle` resource on each flying character (corner speed, formation spacing, how far ahead they push, line wobble, reaction delay) that the 6.1 autopilot reads. The autopilot is an intent source, so this changes only the intent it writes (rules 1 and 2); every drone keeps the one flight model. The steady flyer gets advice lines on fleet events.
  - Acceptance: Over the same route, the bold style finishes ahead of the steady one and the clumsy style deviates from the line the most. Each fleet job still completes in its existing test with every style. Flight model, mass, and assist values are unchanged.
  - Out of scope: Crew calling for rescue, new failure states.
  - Note: `Character.flight_style` points at a `FlightStyle` in `data/crew/styles/` (Dot bold, Marlo steady, Pip clumsy, Ozzie gentle): `push` and `corner_speed` scale the autopilot's speeds, `cut` widens its pass radius, `spacing` keeps a gap from other drones in the `autopilots` group, `wobble` sways the aim off the line (calming within `Autopilot.CALM` of a point), and `delay` holds the old sticks after a waypoint; a null style flies exactly as before. `FleetCrew.fly_as(auto, c)` sets it (fleet and the Lattice's returned drones), and the style with `advice` (Marlo) radios event `advice` (not in `Bark.EVENTS`, like `order`) on relay `leg_done`/`lap_invalid` and a drone finishing its route, once per `advice_gap` and never on a boss job. `tests/test_flight_style.gd` re-runs the inspection, relay and Lattice reclaim completion tests with every pilot in each style, so a new style must still clear the relay's gates.

- [x] **18.12 Radio font**
  - Goal: Radio lines in a chunky, highly legible monospaced pixel font, so typing out reads like a cabinet's comm screen; names in a bolder cut.
  - Context: A CC0 pixel font (for example one of Kenney's), listed in `data/LICENSES.md`, used by the radio panel and `BarkBox` in both front-end skins (17.6). Text still fits the panel at 960×720 and 1920×1080.
  - Acceptance: The radio panel and bark box use the font. The longest existing line fits without clipping at both resolutions. The font file is listed as CC0 with a URL.
  - Out of scope: Changing fonts elsewhere.
  - Note: `BarkBox.FONT` (Pixel Operator Mono HB) and `BarkBox.NAME_FONT` (its Bold cut), both CC0 from https://www.dafont.com/pixel-operator.font, live in `data/ui/fonts/` with the CC0 text and are listed in `data/LICENSES.md`; their `.import` files are checked in (antialiasing, hinting and subpixel positioning off) and must be drawn at `BarkBox.FONT_SIZE` 16 px, the font's native size (8 px per glyph), or multiples of it to stay crisp. The labels carry the font as overrides, so the HUD, board and title radios read the same under either skin; `tests/test_radio_font.gd` wraps every dialogue line, memorial and suggestion in the panel at 960x720 and 1920x1080 (the longest takes two of four lines), so later stories adding longer lines get caught there.

## Epic 19: Every crew member counts

Done when every pilot flies differently from the first race and every support crew member gives something you would miss. Today the pilots' tweaks are about 5 percent on one stat, and the speed governor and the battery assist hide most of that until Act 4. Pilots get an edge that shapes how their assists behave plus a real stat bump; the support crew each give a perk while they are fit to work, so an injury or a death costs something you can feel on top of the consequences in `docs/CHARACTERS.md`. Rules hold: one flight model (rule 1); edges only change assist settings, which still only rewrite `Intent` (rule 2), and never add or remove an assist (rule 5); everything is data on the character (rules 4 and 6); nothing is graded on the camera (rule 8). The autopilot's flying styles (18.11) are a separate thing and keep their own rule.

Pilot edges, each best at one thing:

| Pilot | Best at | Assist settings (others' in brackets) | Stats |
| --- | --- | --- | --- |
| Pip | A bit of everything, most forgiving | Governor 13 m/s (12); auto-level 38° (35°); climb 5 m/s (4); collision guard keeps 0.7 m (0.4) and reacts in 0.2 s (0.3) | +0.25 N thrust, -0.02 drag, +30 s battery |
| Fen | Straight-line speed | Governor 15 m/s; brake's full-stick speed 10 m/s (8) | +0.5 N thrust |
| Moss | Cornering | Auto-level 45°; yaw 130°/s (90°/s) | -0.04 drag |
| Tally | Climbing and endurance | Climb 7 m/s; height lock gain 3 (2); collision guard plans for 8 m/s² braking (6), so it lets you fly closer to walls at speed | +60 s battery |

Crew perks, on while the character is alive and not benched:

| Crew | Perk |
| --- | --- |
| Coach Rin | +25 percent reputation from every job, so team offers come sooner |
| Marlo | Route guidance one step better on every job (none to next leg, next leg to full) |
| Dot | Garage prices 20 percent lower |
| Bea | +15 percent pay on every job |
| Ozzie | An injury benches a crew member for one job instead of two |

- [x] **19.1 Pilot edges are data**
  - Goal: A pilot can carry several stat changes and a set of assist settings, applied to the player's drone wherever `Garage.apply` runs today.
  - Context: `Character.tweak` (one `Upgrade`) becomes `edge: PilotEdge`: a list of stat steps (stat, step, unit) and assist settings (assist id, property, value). Applying it sets exported properties on the drone and on the assist nodes in its pipeline; it never adds or removes an assist and never touches `drone.gd` physics. Settings for an assist the act has already removed do nothing. The existing pilots move their current tweak into the new form unchanged, so this story changes no numbers. Update the pilot line in `docs/CHARACTERS.md` ("one small stat tweak") to describe edges.
  - Acceptance: Each pilot's edge round-trips from data. Applying an edge changes only the listed drone stats and assist properties, in free flight and on a job. An assist the preset has switched off stays off and unchanged. The assist list is identical for every pilot. Current pilot numbers are unchanged.
  - Out of scope: New numbers (19.2), the pilot select screen (19.3).
- [x] **19.2 Four pilots, four edges**
  - Goal: The table above, in data, and each pilot measurably best at their thing in Act 1.
  - Context: Edges from 19.1. Numbers live only in the pilots' `.tres` files. Tests fly the real drone headless with Act 1 assists and scripted sticks.
  - Acceptance: On a 150 m straight at full stick, Fen's top speed is highest and Fen covers it fastest. At full roll and yaw stick, Moss turns through 180° in the least time. At full throttle stick, Tally climbs 30 m fastest. Pip is never last on any of the three and stops furthest from a wall flown at full stick. Without assists (Act 5 preset), each pilot's stat bump still shows: Fen's climb, Moss's top speed, Tally's flight time.
  - Out of scope: Rebalancing jobs, grades, or time limits.
- [x] **19.3 Pilot select shows the edge**
  - Goal: Choosing a pilot is an informed choice: each card says what they are best at and shows it.
  - Context: `PilotSelect` (cards with portrait, role, and today the tweak's name). Each card gets a one-line "best at", the edge in plain words ("Top speed 15 m/s while the governor is on, others 12"), and four bars (speed, cornering, climb, endurance) computed from the edge, not typed in. Fits at 960×720 in both front-end skins.
  - Acceptance: Every pilot card shows best-at text and the four bars. The bars come from the edge data, and the highest bar on each specialist's card is their specialty. Text fits at 960×720 and 1920×1080.
  - Out of scope: Changing pilots mid-job.
- [x] **19.4 Crew perks are data**
  - Goal: A support crew member can carry a perk that is on while they are alive and not benched, answered by one static query.
  - Context: `Character.perk: CrewPerk` (kind and amount). `Perks.amount(kind)` sums the amounts of every fit crew member carrying that kind, so systems ask for a kind and never name a character (as `Consequences` does for deaths). Injured: off until back from the bench. Dead: off for good. Free flight changes nothing.
  - Acceptance: A perk's amount is reported while its owner is active, zero while injured, and zero once dead. Two characters with the same kind add up. No system outside `data/characters/` names a character to get a perk.
  - Out of scope: The perks' effects (19.5, 19.6).
- [x] **19.5 Pay, reputation, and prices**
  - Goal: Bea, Rin, and Dot's perks change real numbers.
  - Context: `Payout.settle` multiplies pay by 1 + the pay perk and reputation by 1 + the reputation perk; `Garage.price` multiplies by 1 - the price perk, after Dot's death markup (which only applies once Dot is dead, so the two never stack). The results screen shows the bonus as its own line ("Bea's rates +120").
  - Acceptance: With Bea fit, a job pays 15 percent more; benched or dead, it does not. With Rin fit, reputation gains are 25 percent higher. With Dot fit, every Garage price is 20 percent lower; after Dot dies, prices follow the existing closed-then-25-percent rule. The results screen names each bonus.
  - Out of scope: New currencies.
- [x] **19.6 Guidance and recovery**
  - Goal: Marlo and Ozzie's perks change how jobs go.
  - Context: Marlo: the job runner raises `Job.guidance` one step (none to next leg, next leg to full) for radar, map, and route ribbon while Marlo is fit; the job's own setting is untouched in data. Ozzie: `Roster.injure` benches for one job instead of two while Ozzie is fit; Ozzie's own injury uses the normal two.
  - Acceptance: A next-leg job shows the full route with Marlo fit and the next leg with Marlo benched or dead. An injury with Ozzie fit benches for one job; with Ozzie benched or dead, two. Grading is unchanged by either perk.
  - Out of scope: Changing the strike rules or adding a way to revive (rule 7).
- [x] **19.7 Show what you'd lose**
  - Goal: The player knows what each crew member brings before anything happens to them.
  - Context: The CREW page shows each character's perk under their status, struck through while benched and gone with a memorial note once dead ("No more site rates"). The confirmation before a job with crew in the field names the perk at risk. The radio's injury line is unchanged; the results screen's injury line adds "out for N jobs: no <perk>".
  - Acceptance: Each support crew row shows its perk. A benched character's perk shows as off with the jobs left. A dead character's row shows the perk lost. The crew-in-field confirmation names each perk at risk.
  - Out of scope: New dialogue lines.

## Epic 20: The crew as people

Done when every crew member looks like a person, not a bubble: a rigged cartoon figure in the 3D world that idles, waves, flinches and cheers, and a head-and-shoulders radio portrait that matches it. Today a crew member in the field is a coloured capsule with a ball on top, and the portraits are round heads. The figures come from a CC0 pack of rigged low-poly people (the user approved a few MB of download), recoloured and dressed per character from data. Everything in Epic 18 stays: the cartoon eyes, expressions, motion, emotes, babble and drone faces. Figures are look only: no collision, and they never touch flight. The dead never appear. Designs are original; the pack only supplies bodies and animations.

- [x] **20.1 Crew looks**
  - Goal: Each crew member has a look in data: which body from the pack, skin tone, hair style and colour, outfit colours, and their accessory (Bea's hard hat, Dot's goggles, Marlo's headset antenna, Fen's visor, Rin's tall hat, Ozzie's ear-muffs, Moss's fin cap, Tally's tuft, Pip's round cap), so every view draws the same person.
  - Context: Download a CC0 pack of rigged, animated low-poly cartoon people as glTF (e.g. Quaternius, Kenney or poly.pizza CC0 entries) into its own empty folder; copy only the .glb/.gltf and textures into `data/models/crew/`, and list each file in `data/LICENSES.md` with its source URL and CC0. Keep the added files under 8 MB. A `CrewLook` resource on `Character` (`look`) holds the body, colours, hair and accessory; accessories are small meshes built in code or from the pack, matched to the existing `shape`. If no CC0 rigged pack can be downloaded without getting round a bot check, stop and say so.
  - Acceptance: Every character has a look. Any two characters differ in at least two of body, skin, hair, and outfit colour. Every model file is listed as CC0 with a URL, and the total stays under 8 MB. Each body has idle, wave, cheer, and flinch (or the closest) animations, found by name in data. A figure built from each look loads in GL Compatibility with no engine errors.
  - Out of scope: Placing figures in jobs (20.2), portraits (20.4).
  - Note: Nine Kenney Mini Characters bodies (CC0, 2.2 MB) sit in `data/models/crew/`; `tools/models/crew_bodies.py` moves their skin, hair, top, bottom and shoe faces into the colormap's empty top row so `scenes/crew/crew_body.gdshader` paints them from the look, and pack details (eyes, glasses, belts, headbands) keep their colours. `Character.look` points at `data/crew/looks/<id>.tres` (body from `data/crew/bodies/`, skin, hair, top, bottom, shoes, accessory matching `shape`, `accessory_color`/`accessory_detail`); `CrewFigure.build(look, height)` makes a collision-free figure with the accessory on a `Head` BoneAttachment3D and `play(action)` for idle/wave/cheer/flinch/hurt, mapped to the pack's idle/interact-right/jump/crouch/sit clips (wave is a reach, the closest the pack has). The pack's own eyes and mouth are still on the head box, at local z 0.16 (20.3 covers them); keep look colours in single `Color` exports, as a `PackedColorArray` export with a default lost its values in the web export.

- [x] **20.2 Crew in the field**
  - Goal: The crew member on a job site is that person, standing there: idling, glancing at your drone, waving when it passes close, flinching and covering up when the hazard warning sounds, cheering when the job completes, and sitting down hurt after a strike.
  - Context: `CrewProp` (`scripts/hazard/crew_prop.gd`, used by inspection, rescue and demolition) builds the figure from the character's `CrewLook` in place of the capsule, with the same height and no collision. Reactions come from the job's existing signals (hazard warning, strike, job complete) and the drone's distance; it only reads them. A prop with no character keeps a plain figure.
  - Acceptance: Each job's crew prop shows the right person. It plays idle by default, waves when the drone comes within a set distance (at most once per pass), flinches on the warning, cheers on completion, and plays hurt after a strike. It has no collision shape and never changes the drone's state. A dead character's prop still never spawns.
  - Out of scope: Faces on the figure (20.3), walking.
  - Note: `CrewProp` builds `CrewFigure.build(look, height)` for a character with a look (keeps the capsule otherwise) and, deferred after `_ready`, finds its character's `HazardZone` and the `JobRunner` under the top scene node, storing them in `zone` and `runner`; `action()` reports what it plays. Hurt (from `runner.crew_struck`) outranks flinch (while `zone.warning()`), which outranks cheer (state COMPLETE), a 1.4 s wave (once per pass: within `wave_distance` 6 m, rearmed beyond `pass_distance` 10 m) and idle; the figure yaws toward a drone within 30 m, except when hurt. CrewFigure now loops idle, wave and cheer; 20.3 should put the face on `prop.figure`'s Head attachment.

- [x] **20.3 Faces on the figures**
  - Goal: The figure's face is the same cartoon face as their portrait: same eyes, brows, mouth and blush, changing expression with what they say, and blinking.
  - Context: Reuse 18.7's approach (`scripts/drone/drone_face.gd`, `scenes/drone/drone_face.gdshader`): the head's face material reads `CharacterPortrait.pose()` fields for the current expression, so there is one source of truth. When the character speaks on the radio, their figure takes the line's face.
  - Acceptance: A figure's face shows the speaker's expression for each line and returns to neutral after it. It blinks on its own rhythm. A dead character's face never shows (the prop does not spawn). The face reads at 3 m in a screenshot of each job site.
  - Out of scope: Lip sync.
  - Note: `CrewFace` (`scripts/crew/crew_face.gd`, a quad on the figure's `Head` attachment at head-bone z 0.168, drawn by `scenes/crew/crew_face.gdshader`) covers the pack's eyes, mouth and Rin's glasses with the portrait's face from `CharacterPortrait.pose()`, blink seed `hash(id)`, on the look's skin lit like `crew_body.gdshader`; Ozzie's beard and every fringe stay in front of it. `CrewProp` makes it with `CrewFace.wear(figure, character)` (null for the dead, and it hides once they die) and points `face.radio` at the job's `BarkBox`, whose current line from that character sets the face and talking; `hold(expr, s)` is a manual override. The face fits the head's skin front (0.24 by 0.271 head units, mouth at 0.52 instead of the portrait's 0.62); 20.4's portraits can stay as they are for it to match.

- [x] **20.4 Portraits as people**
  - Goal: The radio, board and crew-page portraits show each crew member from the shoulders up, with their skin, hair, outfit and accessory from `CrewLook`, keeping the big cartoon eyes and every expression.
  - Context: Redraw `CharacterPortrait` (`scripts/ui/character_portrait.gd`) in code: shoulders and neck under the head, hair behind and in front, the accessory, colours from `CrewLook`. The pose, motion, emote, distress, static, pop-in and dead APIs stay as they are, so callers do not change.
  - Acceptance: Every existing portrait, motion, emote, distress and incoming-call test passes unchanged. Each portrait's skin, hair and outfit colours match its `CrewLook`. All crew are told apart at 32, 64 and 128 px (a screenshot of every face in every expression). The dead pose still shows shut eyes and no motion.
  - Out of scope: New expressions.
  - Note: `CharacterPortrait` draws a bust from the look: shoulders and a round collar in `top` on the bottom edge (they take the face's squash, not its bob), ears, back hair (`long`, `twin_buns`, `bun`, a `crop` ponytail), front hair down to the static `hairline(x)` (kept above every brow) or Ozzie's beard for `bald_beard`, and people-wear per accessory (Pip's peaked cap and Moss's fin cap at `CAP_BOTTOM`, Marlo's headset with the antenna up from an ear cup, Ozzie's ear-muffs); the head's size and place, the face, and every pose/motion/emote/distress/static/pop-in/dead API are unchanged. The static `palette(c)` (skin, hair, top, accessory, detail) and `hair_style(c)` are the one place the portrait reads `CrewLook`, falling back to `colors` without a look; `tests/portrait_probe.gd` renders every face under GL Compatibility for `test_portraits_as_people.gd`.

## Epic 21: The game's song

Done when the title, start page and main menu play the user's own song, "There's Only Love in My Heart" by Avdrav, and every other score is regenerated to sound like it: its tempo, key, chords and instrument colours, still following Epic 16's structure (each act strips back as the assists come off, the Lattice is bare, motifs, tension and weather layers, gates in key). The song is the user's own work, used with their permission; at their direction its audio is taken from their own YouTube upload (https://youtu.be/oT1lXzJybus, 7:33, downloaded as FLAC). Music is still baked offline, never synthesized live.

- [x] **21.1 The song as the theme**
  - Goal: The intro, start page and main menu play the song.
  - Context: The source FLAC goes in `tools/music/source/song.flac` (gitignored; never committed). The song runs 7:33, so the theme is a section of it chosen as a clean loop, sized to fit the budget with its muffled variant. ffmpeg encodes it to Ogg Vorbis in `data/music/` as the `theme` score's one stem, replacing 17.13's generated theme stems (`theme_drums`, `theme_orchestra`), with a loop point at a musical boundary so it repeats cleanly on the menu. Its muffled variant is made the same way as the others. `data/LICENSES.md` / the music licence list record it as the user's own work, used with permission.
  - Acceptance: `data/music/theme.tres` plays the song from the title through the board, in every act, with no gap or click at the loop (checked on the samples either side of the loop point). A job still plays its act's score. The old generated theme stems are gone. `data/music/` stays under 10 MB. Every file is listed.
  - Out of scope: Changing other scores (21.3).
  - Note: `song_theme()` in `tools/music/generate.py` cuts 6:00-7:12 of `tools/music/source/song.flac` (the song sits on an exact 160 bpm grid from 0:00, bars every 1.5 s; the loop is 48 bars of the last chorus, its last half beat crossfaded into the half beat before 6:00) to `data/music/theme_song.ogg` and `_muffled.ogg`, stereo 44.1 kHz `-q:a 4` at `SONG_DB` -3 (matching act 1's full-mix loudness), as `theme.tres`'s one stem `song` (tempo 160, 48 bars, tonic still `key.TONIC` until 21.2); without the FLAC the .tres and manifest are still written and `--check` skips the Oggs. The intro (`data/story/intro.tres`) now plays the theme, `LICENSES.md` has a third licence, `own work`, and the music budget test is 10 MB (all of `data/music/` is about 7.1 MB). For 21.2: tempo 160 (strong half-time feel at 80), sections every 48 bars from 0:24 with a breakdown 5:12-5:30; the key is unclear by chroma (F major 0.46, C major 0.43), so hand-check the tonic; 17.13's brass, strings, timpani and snare instruments remain but no score uses them. `tests/test_song_theme.gd`.

- [x] **21.2 Profile the song**
  - Goal: The song's musical fingerprint as data the generator reads: tempo, key and tonic, chord progression, groove, and the tone of its main instruments.
  - Context: `tools/music/analyze.py` (stdlib plus ffmpeg to decode) writes `tools/music/song_profile.json`: bpm, tonic in Hz, mode, a bar-by-bar chord list, drum pattern onsets, and a spectral envelope per instrument role (bass, pads, lead, drums). `tools/music/key.py` takes the song's tonic, so the motor hum and every in-key sound move with it (`tools/sfx/generate.py --check` regenerated). Hand corrections go in the JSON, which is committed.
  - Acceptance: Running the analysis twice gives the same JSON. The profile's tempo and tonic match the song (checked against values the user confirms or hand-tapped ones in the JSON). `key.py`'s tonic equals the profile's. Both generators' `--check` pass after regenerating.
  - Out of scope: Rewriting scores (21.3).
  - Note: `tools/music/analyze.py` (stdlib FFT, ffmpeg decode, ~30 s, `--check` re-analyses and compares) writes `tools/music/song_profile.json`: 160 bpm from 0:00 (301 bars), tuning +1 cent, home key F major (the key it holds most bars: F 128, C 96 (bars 0-111 open in C), G 48 (bridge, bars 112-159)), so `tonic_hz` 174.72 (F3) and `key.py` now reads it (was D3 146.83); every score, the motor hum and every in-key sound were regenerated in F (all of `data/music/` still 7.5 MB, the theme Oggs unchanged). Per bar `chords` (the theme loop and last part cycle F Bb Gm F Bb Dm, I IV ii I IV vi), `keys` per stretch, `drums` (16-step onset strength, 0 to 1, for kick/snare/hat: snare and hat on quarters strongest on step 8, the half-time backbeat; the kick band also hears the bass's eighths; `swing` 0.542) and `tones` (third-octave `envelope` per role bass/pads/lead/drums, loudest band 0 dB, floor -60, plus median `harmonics_db` 1-8 for bass and lead) are measured heuristics; the `hand` block (bpm, tonic, mode, how) is kept across runs and wins over `measured`. For 21.3: `key.SCALE` is still major just intonation over the new tonic, so the scores are only transposed, not yet rewritten; the user should confirm by ear that the theme's home chord is F. `tests/test_song_profile.gd`.

- [x] **21.3 Every score in the song's sound**
  - Goal: All other music (Acts 1-5, the mantra, crew motifs, tension and weather layers, the Lattice) is regenerated to sound like the song: same tempo feel, key, chord colours and instrument tones, with melodies drawn from it.
  - Context: `tools/music/generate.py` and `instruments.py` read `song_profile.json`; instruments are retuned or added to match its tones. Epic 16's structure stays: Act 1 fully produced, stripping back act by act, the Lattice a bare voice over the drone, motifs per crew member, gates in key. Every existing music test passes, updated only where a test pins an old tempo, tonic or instrument list.
  - Acceptance: Every `Score` uses the profile's tempo (or a stated multiple) and tonic. The generator is deterministic. Every act still has fewer stems than the one before it, as Epic 16 requires. `data/music/` stays under 10 MB. Every file is listed.
  - Out of scope: Live synthesis, new music systems.
  - Note: `tools/music/generate.py` reads `song_profile.json`: every score is `SONG_BPM` 160 times a `TEMPO_MULTIPLES` value (acts 1, 2, 4, placeholder, theme x1; act 3, act 5, lattice, mantra, demo x0.5 at 80), stated per score in the manifest as `tempo_multiple` (with `song_bpm`, `tempo_multiples`); acts 1-4 play the song's chords one per bar (`song_chords`, every other song bar from `HARMONY_BAR` 254: F Bb Gm F Bb Dm F Bb, just ratios with ii on 10/9, listed as `chords`) and its groove (`groove`: snare on its backbeat step, kick on steps 0/4/10, hats at their measured strengths, swung); `instruments.py` gives bass and lead the profile's measured harmonics (within 1 dB of it, a saw was 4-8 dB off), keeps the pad a saw (within 3 dB of the pads envelope), and adds `shaker` and `keys`. To keep strictly fewer stems per act, act 1 has 14 (adds keys, strings, snare, shaker, fill, counter), act 2 13 (adds strings, shaker), act 3 12 (adds shaker), act 4 11 (unchanged list) and act 5 10 (drops reed and frame drum); the mantra and crew motifs are unchanged (melodies are not transcribed from the song: the counter line follows its chords' thirds), all of `data/music/` is 7.4 MB; listen for act 1 at 160 with a half-time backbeat, and whether the ii chord (Gm) and the hook sit well. `tests/test_song_scores.gd`.

## Epic 22: The test path

- [x] **22.1 From a loop to a path**
  - Goal: The test race becomes a point-to-point path that teaches in three parts: a straight run that only tests altitude (gates at different heights), then turns brought in gradually at one height, and finally turns and height changes together, ending at a finish gate.
  - Context: `CourseData` gains `closed` (default true, so the fleet race's loop is unchanged); an open course runs once from the start gate to the last gate, and `Course` finishes the run there instead of counting laps. A new `data/courses/test_path.tres` and map replace the loop in `scenes/jobs/test_race.tscn`; the race's objectives and HUD read "run" rather than "lap" for an open course. AI racers fly it with the 9d1d4ab spline handles. Tests that load the loop for loop behaviour keep it.
  - Acceptance: The first part's gates sit on one straight line with at least three different heights and no turn. The second part's turns grow (each turn's angle at least the one before) at one height. The last part has gates that change both heading and height. The race ends at the last gate, once. Both AI racers finish it. The fleet race still runs its loop with laps.
  - Out of scope: New gate kinds, other courses.
  - Note: `CourseData.closed` (default true) marks a loop; `data/courses/test_path.tres` (16 gates, `closed = false`, start gate at z 60 with the racers moved behind it) is a straight of heights 3-5 m, six left turns growing 15-60 deg at 3 m, then five weaving gates that change heading and height, finishing near the start; its map is `data/maps/test_path.tres`. On an open course `Course.laps()` is 1, `finish_gate()` is the last gate, the run finishes there once (a skipped gate only makes it invalid), `CourseRoute` ends there, `AiPilot` flies an open spline with a `run_out` past the finish and then hovers, and `RaceHud.lap_label()` reads "RUN" with gate n/15; the objectives are labelled "Clean run" and "Best run", and the split delta only shows from a previous run's best. The spotter drill inherits the test race so it flies the path too (AI times about 49-50 s, in line with the Act 1 leaderboard); the fleet race and tests about loop behaviour keep `test_loop.tres`.

- [x] **22.2 The fleet race on a path**
  - Goal: The team relay runs on a point-to-point path too: the path is split into legs, each flown by a different drone, and each handoff happens at the gate where one leg ends and the next begins.
  - Context: Builds on 22.1's open `CourseData` (`closed = false`). `Relay` (6.4) owns the legs; on an open course a leg is a run of gates between two handoff gates (data on the course or the relay, e.g. `leg_ends`), and each drone waits at its leg's start. The relay can use 22.1's test path or its own path in the same three-part shape. G (`send_lap`) sends the selected drone along its leg on autopilot. Grading stays on legs completed and handoff times. Tests that need a closed loop keep `test_loop.tres`.
  - Acceptance: `scenes/jobs/fleet_race.tscn` runs on an open course. Each leg must be flown by a different drone; a leg flown by the wrong drone, one that missed a gate, or one started before the handoff is invalid. Handoff timing shows on the HUD. The race ends at the last gate. A fleet with every pilot style (18.11) still completes it.
  - Out of scope: Opponent fleets, new gate kinds.
  - Note: `scenes/jobs/fleet_race.tscn` now runs `test_path.tres` with `Relay.leg_ends = [4, 8, 11, 15]` (any other fleet size splits the path evenly, `Relay.ends()`/`leg_start(k)`); on an open course the relay places each drone `wait` beside and behind its leg's first gate, tracks each drone's `Run` from the gates' own `passed` signals (a leg is invalid for the wrong drone, a skipped gate, or starting before the handoff, and stays open), and is done at the last gate. `send(d, k = -1)` (G) flies a drone along its own leg (or leg `k`), the HUD's leg line adds "gates a-b", and the closed-loop lap relay is unchanged but no scene uses it now; the command view is at 120 m over (-35, -5). `tests/test_fleet_path.gd` flies the whole relay in every pilot style (about 64-86 s).

## Epic 23: Full gamepad

Done when the whole game, from PRESS START to the Lattice, can be played with a gamepad alone, on desktop and in the browser, and every on-screen prompt names the button the player actually holds.

Today the pad flies the drone (both sticks, Mode 2) and has two buttons: Y (`cycle_camera`) and Start (`reset_drone`). Godot's default `ui_*` bindings give menus A, B, d-pad and left stick, but nothing checks that every screen works with them. Every other action is keyboard-only, and every prompt names a key ("press Enter to launch", "Esc to go back", the controls panel, the board's footer).

Layout (Godot `JoyButton` indices; Xbox names, PlayStation in brackets):

| Button | Flight | Command view | Menus |
| --- | --- | --- | --- |
| Left stick | Throttle (Y), yaw (X) | | Move focus |
| Right stick | Pitch, roll | | |
| A (0) [Cross] | Launch from the briefing | Drop in / back out | Select |
| B (1) [Circle] | Leave dialog (as Esc) | Leave dialog | Back |
| X (2) [Square] | | `send_lap` / `tag_unit` (one per job) | |
| Y (3) [Triangle] | Camera view | Camera view | |
| Back (4) [Create] | Full map | Full map | |
| Start (6) [Options] | Pause (the leave dialog) | Pause | |
| LB (9) / RB (10) | | Previous / next drone | |
| D-pad up (11) | Controls panel | Controls panel | Move focus |
| D-pad down (12) | Reset the drone (free flight) | | Move focus |
| D-pad left / right (13, 14) | Cycle assists / weather (free flight) | | Move focus |
| L3 (7) | Debug readout | | |

The free-flight start-a-job keys (J K L H U) stay keyboard only: they are sandbox shortcuts, and the board starts every job.

- [x] **23.1 Every action has a button**
  - Goal: Every action a player needs has a gamepad binding, laid out as in the table above.
  - Context: `project.godot` InputMap. Start moves from `reset_drone` to a new `pause` action, which `JobRunner` treats as `ui_cancel` (`request_leave`). A new `prev_drone` action joins `next_drone`. `send_lap` and `tag_unit` share X, since no job uses both. Bindings use `device = -1` (any pad). `ControlsHelp` gains `prev_drone` and `pause` rows.
  - Acceptance: Every action in `ControlsHelp.GROUPS` except the start-a-job group and `toggle_mute` (reachable from OPTIONS) has at least one `InputEventJoypadButton` or `InputEventJoypadMotion`. Within one context (flight, command view, menus), no two actions share a button, except `send_lap` and `tag_unit`. Start opens the leave dialog in a live job and `reset_drone` no longer fires on Start. The flight axes are unchanged.
  - Out of scope: Rebinding, prompts (23.2).
  - Note: Start does nothing in the briefing, on purpose (owner's call): only B or Esc goes back to the board from there, so Start never sends a player home by accident. In COUNTDOWN and LIVE it opens the leave dialog.

- [x] **23.2 Prompts follow the device**
  - Goal: Every prompt names the key or the button for the device the player last touched, and switches the moment they touch the other one.
  - Context: A new `InputPrompt` autoload remembers the last device (key or mouse versus pad; stick motion under the deadzone does not count) and its family from `Input.get_joy_name` (Xbox, PlayStation, Nintendo, otherwise generic Xbox names). It emits `device_changed`. `ControlsHelp.key_text` becomes `InputPrompt.text(action)`, returning "Enter" or "A" / "Cross" or "LB" / "D-pad ↓". The prompts are text in the existing fonts, so there are no glyph images and no new assets. Callers that redraw on `device_changed` include `ControlsHelp`, `ControlsHint`, `JobRunner`'s briefing line, the board's `CONTROLS` footer and "Esc to go back", and the fleet, relay and Lattice HUD hints.
  - Acceptance: After a synthetic joypad button event, every prompt names pad buttons. After a key event, every prompt names keys. A PlayStation-named pad reads "Cross" where an Xbox pad reads "A". No script under `scripts/` holds a hard-coded key name in player-facing text; a test greps for "Enter", "Esc", "Space" and "click" in string literals, with an allow-list for the key table.
  - Out of scope: Button images, rebinding.

- [x] **23.3 Menus by pad alone**
  - Goal: Every screen and dialog can be used with A, B, the d-pad and the left stick alone.
  - Context: 17.3 to 17.6 set focus on the board, carousel, pilot select and results. Still to audit: the CREW and OPTIONS pages, the sound dialog's sliders and mute box, the quality `OptionButton` and its popup, the shop and offer dialogs, the launch and leave dialogs, the crew warning and perk-at-risk confirmation (19.x), the map screen, and cutscene skip. A dialog that closes hands focus back to the control that opened it. Holding the stick moves one item per tilt, then repeats; it never skips.
  - Acceptance: A "pad walk" test drives title → board → every menu page → a job briefing → launch → leave dialog → results → board using only `Input.parse_input_event` with joypad events. At every step the focus owner is visible, enabled and not null. B backs out of every page and dialog exactly as Esc does. Sliders move with d-pad left/right. The `OptionButton` opens, changes and closes by pad.
  - Out of scope: New menu screens.

- [x] **23.4 Fleet command on the pad**
  - Goal: The command view (Act 5, the relay, the Lattice) is fully playable with a pad.
  - Context: `CommandView._unhandled_input` handles `drop_in`, `next_drone` and a mouse click. It adds `prev_drone`, and the selection wraps both ways. X runs the job's context action (`send_lap` in the relay, `tag_unit` in the Lattice). The fleet HUD names the selected drone as now.
  - Acceptance: With pad events only, a test selects every drone forwards and backwards (wrapping), drops into one and back out, sends a relay leg and tags a Lattice unit. A mouse click still selects.
  - Out of scope: Box-select, cursor-on-stick.

- [x] **23.5 Pause on Start, and when the pad goes away**
  - Goal: Start pauses any live job. A controller that disconnects mid-job pauses it rather than letting the drone fly on with the last stick input.
  - Context: `JobRunner.request_leave` already pauses the tree under the leave dialog; Start reuses it, with focus on stay (cancel). On `Input.joy_connection_changed`, if the pad that disconnects is the last device used (23.2) and a job is in COUNTDOWN or LIVE, the runner opens the same dialog with the line "Controller disconnected". Reconnecting shows a short "Controller connected" toast and never resumes on its own.
  - Acceptance: Start in LIVE pauses the tree and opens the dialog with stay focused; A on stay resumes. Emitting `joy_connection_changed(id, false)` for the device in use pauses a live job, while the same signal on the board or for another pad does nothing. Reconnecting leaves the game paused until the player chooses.
  - Out of scope: Split-screen, more than one player.

- [x] **23.6 Controller options**
  - Goal: OPTIONS gains a CONTROLLER section covering stick layout, inverted pitch, stick feel, deadzone and rumble.
  - Context: Layout is Mode 2 (default, today's) or Mode 1 (throttle and pitch swap sticks), applied by rewriting the flight actions' `InputEventJoypadMotion` axes. Invert flips pitch's axis value. Stick feel is `PilotInput.expo` (0 to 1, default 0.4) and deadzone is 0.1 to 0.3 (default 0.2) on the flight actions. Rumble on or off feeds 23.7. These are saved in the save file next to the sound settings and applied on boot. Shaping only (rule 2): nothing here touches the flight model.
  - Acceptance: Each setting survives a save and reload. Mode 1 puts throttle on the right stick's Y and pitch on the left stick's Y, and every other action is unchanged. Invert makes stick-up pitch back. Expo and deadzone reach `PilotInput` and the InputMap. The section is usable by pad (the 23.3 walk covers it). The controls panel and prompts show the swapped sticks.
  - Out of scope: Per-button rebinding.

- [x] **23.7 Rumble**
  - Goal: The pad rumbles for the moments that matter: a crash or hard hit (scaled by impact), a gate passed (a short tick), a hazard warning or strike, and a job's end.
  - Context: A small `Rumble` autoload wraps `Input.start_joy_vibration` on the last-used pad, and logs each request the way `Music.log` does so tests can read it. It does nothing when rumble is off (23.6), the last device is the keyboard, or the platform doesn't vibrate (the web export may not; then it is silently skipped). It hooks the drone's existing collision, gate, `HazardZone` warning and `JobRunner` state signals, so no job gets job-specific code (rule 3).
  - Acceptance: Each event logs one request with the listed strength and length, and a harder hit asks for more. Nothing is requested with rumble off or after a key press. Nothing about play depends on rumble.
  - Out of scope: Haptic triggers and other controller-specific features.

- [ ] **23.8 Pad check, and the browser**
  - Goal: OPTIONS has a PAD CHECK page that shows both sticks live, the triggers, and the name of each button as it is pressed. The web build is checked against real pads with it.
  - Context: Browsers only reveal a gamepad after a button is pressed while the page has focus; the title's PRESS START is that press, and the title already accepts joypad buttons. A pad with the browser's standard mapping matches Godot's indices (right stick on axes 2 and 3). The check page makes a mismatch visible instead of a mystery. It shows `Input.get_joy_name` and the 23.2 family.
  - Acceptance: A test feeds joypad motion and button events and reads the page's stick positions and button name. The page is reachable and leavable by pad (B). The owner playtests the deployed build in Chrome and Firefox (and Safari on the Mac) with an Xbox-style and a PlayStation pad and records the results in the story's Note.
  - Out of scope: Remapping non-standard pads.

## Epic 24: Jaisalmer

Done when the game is called Jaisalmer everywhere a player or a contributor sees it, it is served from the owner's own domain, and nobody's save is lost on the way.

Do not start this epic until the owner says go.

Where "Drone Sports" is today: `project.godot` `config/name` (which also names the browser tab and, on desktop, the `user://` folder the save lives in), the title screen's logo (`title_screen.gd`), the intro's title card (`data/story/intro.tres`), the crawl's last line (`data/ui/crawl.tres`), `tests/test_smoke.gd` and `tests/test_title_crawl.gd`, and the headings of `CLAUDE.md`, `README.md`, `docs/VISION.md`, `docs/CHARACTERS.md` and `docs/BOSS.md`. The site is https://avdrav1.github.io/drone-sports/ and the repo is `avdrav1/drone-sports`.

In the fiction, the sport keeps its name: people still fly drone sports, and only the game is called Jaisalmer. VISION's "Drone sports" pillar stays as written.

Owner decisions:
- The crawl's last line: "THIS IS JAISALMER" (decided).
- The domain: `jaisalmergame.com` (decided). Both the bare domain and `www.` must work (decided): the bare domain goes in `CNAME`, and GitHub Pages redirects `www.` to it once both have DNS records.
- Rename the GitHub repo (24.5): yes (decided).
- Web saves do not carry over (decided): a browser keeps saves per site, so careers saved at avdrav1.github.io start fresh on the new domain.
- Which font the title is lettered in (24.6), from the comparison sheet.

- [x] **24.1 The name in one place**
  - Goal: Every player-facing "Drone Sports" reads "Jaisalmer", and the name lives in one place so it never drifts again.
  - Context: `config/name` becomes "Jaisalmer", and that setting is the one source: the title logo and the intro title card read it (upper-cased) instead of holding the text. The Web export uses `config/name` for the page `<title>`. The crawl's last line is "THIS IS JAISALMER". `config/icon` points at `res://icon.svg`, which does not exist; that is out of scope here, but noted.
  - Acceptance: `config/name` is "Jaisalmer". The title screen and intro title card show "JAISALMER" and change with the setting. The crawl ends on the decided line. No string literal under `scripts/`, `scenes/` or `data/` contains "Drone Sports" in any case (a test greps). Lower-case "drone sports" as the name of the sport, in dialogue or lines, is allowed and listed in the test's allow-list. The exported `build/web/index.html` title reads "Jaisalmer".
  - Out of scope: A new logo or icon, new art.

- [x] **24.2 Saves survive the rename**
  - Goal: A desktop player who saved under Drone Sports opens Jaisalmer and finds their career where they left it.
  - Context: On desktop, `user://` is `app_userdata/<config/name>`, so renaming moves it, and `SaveGame.path` (`user://save.json`) would come up empty. At boot, before `SaveGame.load_all`, if `user://save.json` is missing and the old folder (`.../app_userdata/Drone Sports/save.json`, found from `OS.get_user_data_dir()`'s parent) has one, it is copied across once. The old file is left in place. On the web, `user://` does not depend on the name, so nothing moves; the domain move starts web saves fresh (decided).
  - Acceptance: With a save only in the old folder, boot copies it, and the career, roster status (dead stay dead) and wallet match it. With a save already in the new folder, nothing is copied or overwritten. With no old save, nothing happens. It runs once and never deletes anything. Tests use a throwaway pair of folders, not the real ones.
  - Out of scope: Save format changes.

- [x] **24.3 The docs and the repo say Jaisalmer**
  - Goal: Anyone opening the repo sees Jaisalmer.
  - Context: Retitle `CLAUDE.md` ("# Jaisalmer"), `README.md`, and the VISION, CHARACTERS and BOSS headings. The README also drops its stale Cloudflare/wrangler steps for the GitHub Pages deploy that `scripts/ship.sh` really does. VISION's opening gains one line: the game is Jaisalmer, and the sport in it is drone sports. Older backlog stories keep their text; they are history.
  - Acceptance: No file outside `docs/BACKLOG.md` says "Drone Sports" as the game's name (a test greps the repo's .md files with the same allow-list as 24.1). The README's deploy steps match `scripts/ship.sh`.
  - Out of scope: Rewriting backlog history, renaming the local folder.

- [ ] **24.4 Served from the domain**
  - Goal: The game is served from the owner's domain over HTTPS, and every deploy keeps it there.
  - Context: GitHub Pages reads a custom domain from a `CNAME` file at the root of `gh-pages`. `scripts/ship.sh` force-pushes that branch from `build/web`, so the file must be in every deploy: the domain lives in a checked-in `web/CNAME`, and `ship.sh` copies it into `build/web` before pushing. It sets the Pages `cname` through `gh api` (and `https_enforced` once GitHub has issued the certificate), and prints the domain's URL instead of the github.io one. Owner steps, which an agent cannot do: register the domain, then add the DNS records (A or ALIAS records for GitHub Pages' four IPs on the apex, and/or a `www` CNAME to `avdrav1.github.io`), and verify the domain in GitHub's settings.
  - Acceptance: `web/CNAME` holds exactly `jaisalmergame.com`. A deploy's `build/web` contains it. Both `https://jaisalmergame.com/` and `https://www.jaisalmergame.com/` load the game, the second by redirect (owner checks once DNS is set). `ship.sh` prints `https://jaisalmergame.com/`. The game loads at the domain over HTTPS, and the old github.io address redirects to it (owner checks and notes it in the story's Note). The build uses only relative paths, so moving from `/drone-sports/` to `/` breaks nothing.
  - Out of scope: Other hosts, analytics.

- [ ] **24.5 Rename the repo**
  - Goal: The GitHub repo is `avdrav1/jaisalmer`.
  - Context: Do it after 24.4, so the custom domain already serves the game and nothing links to a path that is changing. `gh repo rename jaisalmer` keeps a redirect from the old name; each local clone and worktree updates `origin` with `git remote set-url`. `ship.sh` reads the repo from `gh`, so it needs no change.
  - Acceptance: `origin` points at `avdrav1/jaisalmer`, `scripts/ship.sh` deploys from it, and the domain still serves the game.
  - Out of scope: Renaming the folder on disk.

- [ ] **24.6 The name, lettered like Hindi**
  - Goal: The title "JAISALMER" is written in English letters drawn in the manner of Devanagari: the letters hang from one continuous headline bar (the shirorekha), with thick and thin strokes and a few hooked strokes below the line, so at a glance it reads like Hindi script and on a second look it reads "Jaisalmer".
  - Context: Today the title screen's logo (`title_screen.gd`, `title_label`) and the intro's title card use the cabinet skin's display font, Press Start 2P. The logo becomes its own `TitleMark` control used by both, with the name from `config/name` (24.1). The look comes from an open-licence (OFL) font with a Devanagari-inspired Latin face. Candidates to compare include Yatra One, Rozha One, Teko and Kurale; freeware "Hindi-look" fonts with unclear licences are not used. The bar is drawn by the control across the letters' tops, running a little past the first and last letter, because no candidate draws one across Latin text. Before choosing, a comparison sheet renders "JAISALMER" in each candidate with the bar and goes to the owner, who picks one. The font goes in `data/ui/fonts/` with its licence and a line in `data/LICENSES.md`, like Press Start 2P. Everything else on the title screen (PRESS START, the crawl, the menu) keeps the arcade font.
  - Acceptance: The title screen and the intro card draw the name with the chosen font and an unbroken headline bar touching the top of every letter, wider than the word on both sides. It is crisp and fully on screen at 960×720 and 1920×1080 and in the web build. It reads `config/name`, so a changed name redraws with no other edit. The font's licence file is in the repo and listed. A test checks the bar spans the word and that the control uses the font; the look is the owner's call on a rendered screenshot.
  - Out of scope: A new icon, Devanagari text (the name stays in English letters), the rest of the UI's fonts.

## Epic 25: Names from the epics

Done when every character carries a name from the Ramayana or the Mahabharata, chosen for what they do in the game, and the boss is Ravana.

Do not start this epic until the owner says go.

Each name echoes the character's job: the student archer flies, the far-seeing narrator spots, the bridge-builder fixes the drones, the healer is the medic. Personalities, edges, perks, voices (babble), faces and risk stay as they are; only names (and, in 25.2, ids) change. Characters still have no stated pronouns: by name, or "they".

| Id now | Name now | Role | New name | New id | Why |
| --- | --- | --- | --- | --- | --- |
| `pip` | Pip | Rookie pilot, the player's avatar | Arjuna | `arjuna` | The student archer, the one everyone trains |
| `rin` | Coach Rin | The scout who recruits you, story voice | Drona | `drona` | Arjuna's teacher, who finds and trains talent |
| `marlo` | Marlo | Spotter, calls gates and hazards | Sanjaya | `sanjaya` | Sees the whole battlefield from afar and narrates it |
| `dot` | Dot | Mechanic, sells upgrades, complains | Nala | `nala` | The engineer who built the bridge to Lanka |
| `bea` | Bea | Demolition foreman, calls the collapse | Bhima | `bhima` | The strongest of the brothers; brings things down |
| `ozzie` | Ozzie | Medic, the one lost in rescue jobs | Sushena | `sushena` | The healer of the Ramayana, who sent for the life-giving herb |
| `fen` | Fen | Sprint pilot, hard launch | Abhimanyu | `abhimanyu` | Young and fast, charges straight in |
| `moss` | Moss | Glide pilot, clean lines | Jatayu | `jatayu` | The great bird, who glides |
| `tally` | Tally | Long-haul pilot, easy on the cells | Hanuman | `hanuman` | The great crossing of the ocean: the longest flight in the epics |
| (boss) | The Lattice | The boss | Ravana | `ravana` | The ten-headed king of Lanka |

Owner decisions (all decided):
- The names in the table, Hanuman for Tally included.
- The boss is called Ravana everywhere a player sees it, and its units are "his heads". The fight does not change (still disabled, never destroyed, rule 9). The code's `Lattice*` class names stay, as an internal name.

- [x] **25.1 New names on screen**
  - Goal: Every character the player sees, hears about or reads about uses the new name.
  - Context: `name` on each `data/characters/*.tres`, the speaker names and lines in `data/dialogue/*.json` and `data/radio/`, job texts in `data/jobs/` (briefings, summaries, memorial lines), team texts in `data/teams/`, cutscene beats in `data/story/`, and any player-facing string under `scripts/` (for example, crew-warning and CREW-page text). Ids stay as they are in this story, so saves and code are untouched. Lines that rhymed or punned on an old name are rewritten. Each character's CREW row gains one short "named for" line about their namesake (for example, "Named for the engineer who bridged the sea to Lanka").
  - Acceptance: No player-facing text under `data/` or `scripts/` holds an old name (a test checks every character's old name, case-insensitive and as a whole word, with an allow-list for ids). The title, board, CREW page, radio, cutscenes and results show the new names. Every character's "named for" line exists and fits its row at 960×720 and 1920×1080. Every existing test passes.
  - Out of scope: Ids, the boss (25.3), new lines beyond the renames.

- [x] **25.2 New ids, and saves that follow**
  - Goal: The ids match the names (`arjuna`, `drona`, and so on), and a save made with the old ids loads with everything intact.
  - Context: Ids are keys in the save (roster status, strikes, injuries, the chosen pilot, crew assignments), in jobs' `crew_in_field`, in teams, in the music motifs (`motif_bea` becomes `motif_bhima`: `tools/music/generate.py` names the stems, and the regenerated files' names change, not their sound), in `data/dialogue/<id>.json` file names, and across `tests/`. `SaveGame` gains a one-time id migration (old → new map) at load, so a dead character stays dead under the new id (rule 7). `.tres` files are renamed to the new ids, and every `res://` path follows.
  - Acceptance: No `.tres`, `.json`, `.gd` or `.py` file holds an old id except the migration map and its test. An old-id save loads with the same statuses, strikes, chosen pilot, wallet and reputation under the new ids, and saves back with new ids only. The music check (`generate.py --check`) passes with the renamed motif stems, and data/music stays under its size cap. Every existing test passes.
  - Out of scope: Save format changes beyond the ids.

- [x] **25.3 The boss is Ravana**
  - Goal: The boss is Ravana wherever a player sees it: its name, its lines, the job's title and briefing, the HUD and the music listing.
  - Context: `data/boss/lattice.tres` and `lattice_job.tres`, `data/dialogue/lattice.json`, the Lattice HUD, and anything that says "Lattice" or "the units" to the player. The ten units are Ravana's heads in what the player reads (if the fight has a different number, the text says "heads" without a count; the fight does not change). The fight stays a disabling, never a destruction: no explosions and no destruction objective (rule 9). `enabled = false` still keeps everything about the boss from loading. Internal names (`LatticeFight`, `BossGate`, file names) may stay.
  - Acceptance: No player-facing string says "Lattice". The boss's name shows as "Ravana" in the job board, briefing, HUD and lines. The boss-disabled tests still prove nothing about the boss loads. The fight's existing tests pass unchanged.
  - Out of scope: New mechanics, new art.

- [x] **25.4 The docs and the rules**
  - Goal: The docs and CLAUDE.md describe the new cast and Ravana.
  - Context: `docs/CHARACTERS.md` (cast table, strike examples and consequences), `docs/BOSS.md`, `docs/VISION.md` mentions, and CLAUDE.md rule 9. That rule says the boss's design is original and imitates no existing franchise. Ravana comes from the epics, not a franchise; the rule is reworded to "The boss (Ravana) is a job like any other…", and keeps "disabled, never destroyed" and "no explosions". The cast's namesakes are treated with respect: no line mocks a namesake, and no deity is played for laughs.
  - Acceptance: The docs use the new names and ids throughout (a test greps the .md files outside BACKLOG.md for old names, as in 25.1). Rule 9 names Ravana and keeps the disable-only rule. Older backlog stories keep their text.
  - Out of scope: Rewriting backlog history.

---

## Epic 26: Faces from the epics, and a radio you can read

Done when every crew face is drawn bigger and more lifelike, as its namesake from the Ramayana or the Mahabharata, and the radio's lines are big, stay up long enough to read, and scroll as a chat.

Owner's direction: "make bigger, better drawn faces … but make the characters explicitly Indian mythology." Faces stay drawn in code (no image files), but leave the Saturday-morning cartoon (18.1, 18.2) for a painted, lifelike style. Each character looks like their namesake, in that figure's traditional iconography. The namesakes are treated with respect: Hanuman is worshipped, so Hanuman's face is dignified and never comic, and no face is played for laughs. Characters still have no stated pronouns in the game's text.

Order: the face rig (26.1), then the looks (26.2), then the sizes (26.3); the radio stories (26.4, 26.5) can run beside them; docs last (26.6).

| Id | Namesake | Drawn as |
| --- | --- | --- |
| `arjuna` | Arjuna, the archer prince | A young prince: a gold crown (mukut), long dark hair, the bow Gandiva over the shoulder |
| `abhimanyu` | Abhimanyu, the young warrior | A youth in a warrior's helmet and armour, with a chakra (wheel) emblem |
| `bhima` | Bhima, the strongest brother | Broad and heavy-browed, a thick moustache, the gada (mace) on the shoulder |
| `drona` | Drona, the teacher | An elder brahmin teacher: white beard, a tilak, rudraksha beads, a bow behind |
| `sanjaya` | Sanjaya, who saw the battle from afar | A court narrator in a turban, with a soft glow at the brow for the divine sight |
| `nala` | Nala, who bridged the sea | A vanara (monkey-faced) builder, with a stone marked "Rama" and a builder's sash |
| `sushena` | Sushena, the healer | An elder vanara physician, with a sprig of the sanjivani herb |
| `jatayu` | Jatayu, the great bird | A great vulture: a hooked beak, a feathered crest, a gold neck ring |
| `hanuman` | Hanuman, who leapt to Lanka | A vanara with a crown, the gada, and a calm, devoted face |

Assumption to confirm: Nala and Sushena are vanaras in the Ramayana, so they are drawn as vanaras, as Hanuman is. Jatayu is drawn as a bird. Ravana (the boss) has no portrait, only its dot grid (`scripts/boss/chorus.gd`), and is out of scope.

- [x] **26.1 A lifelike face rig**
  - Goal: `CharacterPortrait` draws a lifelike, painted head and shoulders in place of 18.1's cartoon: human (and vanara and bird) proportions, a nose, smaller eyes with irises and lids, soft shading on skin and cloth (gradients, a key light and a shadow side), and hair or fur with strands, not one flat shape.
  - Context: `scripts/ui/character_portrait.gd`. `pose(expression, t)`, EXPRESSIONS, DISTRESS, blinking on the seeded timer, `talking`, `look_at`, `pop_in`, `signal_lost` and the dead (greyed, eyes closed, still) all keep their API, so every place a face shows keeps working. 18.2's cartoon motion (squash and stretch, eye pops, the hop) becomes subtle: a breath, a small head tilt, the jaw moving while talking. Drawing stays in `_draw` (no image files, no shaders the web build lacks). Three head types: human, vanara and bird, picked by data (26.2).
  - Acceptance: Every expression still gives a distinct pose (17.1's checks still pass). A face drawn at 256 px has a nose, irises and shading (a test reads the draw calls or a rendered image's colour spread, not exact pixels). No face uses the cartoon outline or the two shine dots. Every character draws without errors at 48, 128 and 256 px. The dead are greyed with eyes closed. Talking moves the mouth; a dead face never moves.
  - Out of scope: Image-file portraits, lip sync, 3D heads.
  - Note: `CharacterPortrait` paints in layers of triangles with a colour per vertex (`CharacterPortrait.Paint`: `dome` for lit rounded forms, `shaded`, `soft` glazes, `stroke` for locks and lashes, each edge faded over a pixel), lit by `Paint.LIGHT` from the upper left with a warm shadow side. The still layers (back, body, head, jaw, front, held) are built once per character, size and death by the static `paint(c, s, dead)` and kept as ArrayMeshes; the eyes, brows and mouth are kept per pose rounded to a fiftieth, so a face costs a few draw calls a frame. The head is `HEAD` 0.22 of the size, its centre `HEAD_Y` above the middle; `CrewLook.head` picks one of `HEADS` (human, vanara, bird; every look is human until 26.2). `painted_motion()` keeps `SUBTLE` 0.3 of 18.2's `motion()` plus a sway and a tilt per expression (`TILT`), and the jaw layer drops by `jaw(p)` as the mouth opens; `paint_parts(c, s)` lists what is painted for tests. With this story, tests that checked the cartoon look changed: 18.1's big-eye, headwear-gap and antenna-outline checks became an eye-proportion and brow-below-hairline check, 20.4's probe counts a look colour lit or in shadow and its hair check uses `brow_reach()`, 18.10's wince is measured against the open neutral eye, and `pupil_center` moves the iris by the eye's height as well as its width.

- [x] **26.2 Looks from the epics**
  - Goal: Each crew member is drawn as their namesake, per the table above.
  - Context: `data/crew/looks/*.tres` (CrewLook: colours, accessory) gains the head type (human, vanara, bird) and the iconography: crown, helmet, turban, beard, tilak, beads, glow, and the held object (bow, gada, chakra, stone, herb). Data over code: a new look is a .tres, not a branch in the portrait. The CREW page's "named for" lines stay. Colours from the traditional depictions: Arjuna's and Hanuman's gold, Drona's white and saffron, and so on.
  - Acceptance: Every character's look names its head type and at least one item of iconography from the table, and the portrait draws it (a test checks each look against the table). Nala, Sushena and Hanuman are vanaras; Jatayu is a bird; the rest are human. No two faces share the same headwear and held object. Faces still read at 48 px: each one's silhouette differs from every other's (a test compares their rendered outlines at 48 px).
  - Out of scope: New characters, changing names, lines or voices.
  - Note: `CrewLook` gains `head`'s company: `headwear` (one of `CrewLook.HEADWEAR`: crown, helmet, turban, band, crest), `hair_cut` (`HAIR`; empty takes the body's), `beard` (`BEARDS`), `held` and `held_side` (`HELD`: bow, gada, chakra, stone, herb), `marks` (`MARKS`: tilak, tripundra, glow, earrings, necklace, beads, sacred_thread, armour, sash, neck_ring), `age` and `build`; `validate()` checks each. `CharacterPortrait._paint_iconography` paints them from the look's colours (`accessory_color` for gold or steel, `accessory_detail` for gems and the sash, `top` for cloth, armour or wings), each headwear sitting at `HEADWEAR_BOTTOM` above the brows. The looks: Arjuna crown, long hair and bow; Abhimanyu helmet, curls, armour and chakra; Bhima band, moustache, gada and a broad build; Drona white jata and beard, tripundra, rudraksha beads, sacred thread and bow; Sanjaya turban and the glow of the divine sight; Nala a vanara with a builder's sash and a stone marked "राम"; Sushena a white-furred elder vanara with beads, tilak and the sanjivani herb; Jatayu a great bird with a crest and a gold neck ring; Hanuman a vanara with a crown, tilak, kundala and the gada. Look colours changed to match, so the 3D crew figures change colour too. `tests/portrait_probe.gd` also draws every face at 48 px and reports `outlines`, the least share of a 48 px square where two silhouettes differ; 20.4's probe now counts a colour down to the painted shadow's depth. The still layers take about 11 ms a face to build on desktop, once per size.

- [x] **26.3 Bigger faces**
  - Goal: Faces are much bigger everywhere they show.
  - Context: The radio panel (`BarkBox.FACE`, 80 px now), the CREW page rows (64) and cards (88), pilot select (64), results (48), the crew warning, the race and flight HUD pilot face, the fleet command view, and the intro's portraits. Roughly doubled: the radio to 192 px, CREW and pilot select to 160, results to 112, the HUDs to what fits beside their readouts at 960×720. The layouts move to fit; nothing overlaps.
  - Acceptance: Each place's face is at least twice its old size, or at the HUD limit stated in the story's test. At 960×720 and 1920×1080 no face overlaps text or another control (a test checks the rects). Pad focus and mouse clicks still reach every control.
  - Out of scope: New screens.
  - Note: Every face is at least twice its old size, none needing a HUD limit: the job card's comms face 128 (`JobBoard.COMMS_FACE`), a CREW row 176 (`CREW_FACE`), pilot select 128, or 160 on a screen 900 px tall (`PilotSelect.FACE`, `FACE_BIG`), results 112 (`Results.FACE`), the crew warning 144 on an 84 px disc (`CrewWarning.FACE`, `DISC`), the flight HUD 112 and the race HUD 128 (`PILOT_FACE`), the fleet command view 68, and the intro's card 320 (`CutscenePlayer.PORTRAIT`). Layouts moved: on a job card with someone on comms, Fly or Locked sits under their line beside the face (`fly_button` and the new `lock_label` find them), so the card keeps its height; a pilot card stacks the face over the name and the role (the FLYING tag on the role's line), Back sits in the top left corner, and the edge text sets tighter; the results rows sit in a ScrollContainer that takes the height the screen leaves (`fit_rows`), up and down scroll it, and the final crew pass runs two to a row (`Farewells`); the race HUD's face sits in the corner with the name, position and lap under it (`readouts_rect`), clear of the briefing line and the Act 1 leaderboard; the crew warning sits lower, clear of the job state line; a fleet face is centred over its drone's name. The radio panel's face is 26.4's.

- [ ] **26.4 Radio text you can read**
  - Goal: The crew's lines on the radio are bigger and stay up long enough to read.
  - Context: `scripts/ui/bark_box.gd`. The pixel font stays crisp only at whole multiples of 16 px, so lines go to 32 px (the name too). Lines stay up for a time set by their length (about 2 s plus 0.07 s a character, at least 5 s) instead of a flat `hold` of 3.5 s. The panel grows to fit the bigger face (26.3) and text. Urgent lines still cut in at once.
  - Acceptance: Lines draw at 32 px. A line of N characters stays at least max(5, 2 + 0.07 N) s after it finishes typing. The longest existing line fits the panel at 960×720 and 1920×1080 (18.12's test, at the new size). Urgent lines still cut in.
  - Out of scope: The chat log (26.5).
  - Note: `BarkBox.FONT_SIZE` is 32 and `BarkBox.FACE` 192. The panel is a low bar (`panel_rect`, 720×164, its top on the screen's lower third at 960×720) with the face on a tab standing up out of its left end (`face_rect`), below the speed gauge. A line holds `hold_time(text)` after typing (`hold_base`, `hold_per_char`, `hold_min`) when nothing waits; a waiting line still takes the channel after `beat`, as before. Left unticked, waiting on the owner: "A line of N characters stays at least max(5, 2 + 0.07 N) s after it finishes typing" is met only for a line nothing replaces. A waiting line still takes the channel after the 1 s `beat`, so a line can leave the bar about 1 s after it types out. Making waiting lines sit out the hold would break 17.7 (two chatter lines raised together both play; chatter waiting over 4 s is dropped) and 17.8 (a near miss during the briefing line is called on the radio, `test_flight_lines`). The owner picks one: waiting lines sit out the hold (and 17.7/17.8 change), or the criterion reads "when nothing replaces it" (a replaced line stays readable in 26.5's chat at 16 px). The jobs' briefing `ControlsHint` moved from under the bar to just above it, between the face and the radar, wrapping to two lines at 960 wide, only between items (`ControlsHint.wrapped`). The board's foot is all menu and card, so there the panel hangs from the top over the header (`at_top`, solid). The Lattice's line (`ChorusBox.label_rect`) moves up above the bar where the bar reaches it. A pilot speaking (not on the roster) gets their face and role (`BarkBox.speaker`). A line longer than the bar's three lines ends in an ellipsis (`BarkBox.MAX_LINES`), and the board's header and how-to line fade out while the bar hangs over them. `tests/test_radio_readable.gd`.

- [x] **26.5 The radio as a chat**
  - Goal: The radio keeps the last few lines on screen as a scrolling chat, so a line missed mid-flight can still be read.
  - Context: `BarkBox` and the radio panel. The newest line types out at the bottom with its speaker's face and name; older lines move up, smaller faces beside them, and fade with age. Up to four lines show; older ones scroll off the top. The chat empties after a while with no new lines. It sits low on the left, as now, and never covers the gates or the drone's centre of the screen. On the board and the title the same chat shows the goodbye and the other front-end lines.
  - Acceptance: After three lines, all three show, newest at the bottom, each with its speaker's name. A fifth line scrolls the first one off. Lines older than 20 s fade out. The chat never covers the middle third of the screen at 960×720 or 1920×1080. Pausing holds the chat as it is.
  - Out of scope: Replying, a full radio history page.
  - Note: `BarkBox.chat` holds the last `CHAT_LINES` (4) lines, oldest first; the newest types out in the bar, the older ones stack above the face in `row_rects`, at the font's native 16 px with 48 px faces and the speaker's name, in a column `chat_width` wide that stops short of the screen's middle third (taken as the centre cell of a 3×3 grid; a full-height or full-width band leaves no room for a 192 px face). A line fades once `FADE_AFTER` (20 s) old over `FADE_TIME`; when the newest has faded the chat is empty and hidden. `showing()` still means the newest line is within its hold, so faces on props (CrewFace) keep 26.4's timing. The flight HUD's speed gauge moves to the right, stacked above altitude (`FlightHud.SPD_RISE`), so in flight the left column from the job panel down to the face is the chat's. The rows form one stack and end at the first thing they must not cover (`BarkBox.avoid`: a sibling `FlightHud.readout_rects`, the job panel and the speed and altitude gauges, and controls in the `radio_avoid` group, the fleet jobs' Board and Stations); a row with no room left does not show. After three lines all three show in flight at 960×720 and 1920×1080, even with the longest lines; four short lines all show. On the board the panel hangs from the top (26.4), the rows hang below the face and stop at the first button or card (`JobBoard.radio_clear`), and the chat goes once the newest line's hold ends (`linger` false) rather than after 20 s. `tests/test_radio_chat.gd`.

- [x] **26.6 The docs show the faces**
  - Goal: `docs/CHARACTERS.md` describes each character's look as their namesake.
  - Context: The cast table gains a "Drawn as" column from the table above. The respect line covers the faces too.
  - Acceptance: Every character's row has a "Drawn as" entry matching their look. The respect line names the faces. 25.4's docs tests still pass.
  - Out of scope: Backlog history.
  - Note: The cast table gains a "Drawn as" column and a row for each pilot avatar (Abhimanyu, Jatayu, Hanuman), so every character with a portrait has one; `tests/test_docs_faces.gd` reads each entry against the character's `CrewLook` (a vanara or bird head, and every headwear, hair, beard, held object and mark it names). The respect line covers the faces and Hanuman's dignified face. Rule 5 (round, big-eyed, placeholder shapes) now describes the painted faces, the intro line drops "small, round", and the species question is ticked: humans, vanaras and a great bird.

---

## Epic 27: Your ride

Done when the player can make each drone their own: its paint, lights, decals and name, and parts that trade one strength for another. All of it is set up in a hangar on the board, unlocked with job money or by achievement, and every drone in a fleet is set up on its own.

Owner decisions (all decided):
- Scope: looks, and parts with trade-offs.
- Unlocks: both with job money and by achievement.
- Fleet: each fleet drone is customized separately.

Rules this epic keeps: one flight model (rule 1), so parts only change the drone's exported stats (rule 5), never add or remove an assist and never change physics code. Looks are visual only: `DroneLook` never touches physics, and nothing is graded on looks (rule 8). Data over code (rule 4): liveries, decals, parts and unlocks are `.tres` resources under `data/garage/`. The decals and patterns are original art made in code or in the repo, in Rajasthani and epic motifs (block print, jharokha lattice, chakra, lotus); no team, brand or franchise logos beyond the game's own teams.

Order: 27.1, then 27.2 and 27.4 (independent), then 27.3, 27.5, 27.6, 27.7.

- [x] **27.1 A livery in the save**
  - Goal: Each drone slot has a livery (its looks and its name) and a set of parts, kept in the save. Slot 0 is the player's drone; slots 1 and up are the fleet's, as many as the largest fleet.
  - Context: A `Livery` resource: body, arm, prop and canopy colours, light colour, decal id and its colour, a race number, and a name. Parts are ids per kind (frame, props, battery; 27.4). The save gets a "hangar" section (slot -> livery and parts, plus what is unlocked), read and written like `Garage`'s "upgrades". A new or old save starts every slot on the default livery, which is today's look exactly, and the default parts, which change nothing.
  - Acceptance: A save with no hangar section loads with every slot on the default livery and parts, and a drone looks and flies exactly as before (stats unchanged). Changing slot 2's livery and parts and reloading keeps them, and slot 0 is untouched. An unknown decal or part id in a save falls back to the default instead of failing.
  - Out of scope: The look itself (27.2), parts' stats (27.4), the hangar page (27.5).

- [x] **27.2 Paint, lights and decals**
  - Goal: A drone wears its slot's livery: colours on body, arms, props and canopy, under-glow and arm lights in the light colour, a decal on the top of the hull, and its race number.
  - Context: `scripts/drone/drone_look.gd` builds the body from parts in `_build()`; it reads the livery there, and `still_mesh` (the boss's shell) keeps the default. Lights keep the white front and red back marks that show heading, with the livery's colour as an under-glow and arm strips, so heading still reads at a glance. Decals (at least eight to start: block print, jharokha lattice, chakra, lotus, peacock, sun, stripes, the team's emblem in team colours) are textures drawn in code or files made in the repo, with their licence listed. Works on the web build (GL Compatibility) and the fleet draws many drones, so materials are shared per livery, not per part.
  - Acceptance: A drone with a non-default livery shows each colour on its part (a test reads the materials). The front and back heading lights are present in every livery. Every decal draws on the hull without errors. The default livery looks as before (the materials match today's). Ten drones with ten liveries in one scene add no more than ten sets of materials.
  - Out of scope: Choosing them (27.5), unlocks (27.3).

- [x] **27.3 Unlocks: money and achievements**
  - Goal: Every look and part that is not a default is locked until bought with job money or earned by an achievement, and the player can see how to unlock it.
  - Context: An `Unlock` on each item: a price (from the wallet, as `Garage` upgrades are), an achievement, or both (either one opens it). Achievements are data: a job completed, a job completed under a time or with no crashes, a best payout reached, a reputation level with a faction, a story flag, or the fleet first flown. Earned unlocks open at the job's results, with a line on the results screen and a radio line. Price markups and perks that already touch the shop (shop_closed, Story 7.6, and the price perk, Story 19.5) apply to hangar prices too.
  - Acceptance: A locked item cannot be applied; buying it spends exactly its price, and an unaffordable item cannot be bought. Meeting an achievement opens its item once, shows it on the results screen, and keeps it unlocked after reload. An item with both a price and an achievement opens by either. Every item names how it unlocks. The shop markup and price perk change hangar prices as they do upgrades.
  - Out of scope: New jobs made only for unlocks.

- [x] **27.4 Parts with trade-offs**
  - Goal: Parts that change how the drone flies by trading one strength for another: frames, props and batteries.
  - Context: A `Part` is a kind (frame, props, battery) and steps on the drone's exported stats (mass, drag, angular drag, max thrust, arm length, yaw torque, battery flight time), applied by `Garage.apply` with the upgrades and the pilot's edge (Stories 7.2, 19.1), in the same way, so the flight model and assists are untouched (rules 1, 2, 5). Start with three frames (light racer: fast and twitchy, short battery; heavy hauler: steady in wind, slow to turn; freestyle: balanced, quick to yaw), three props (grip, speed, quiet efficiency) and three batteries (long range and heavy, light and short, standard). A frame also changes the look: arm length and hull shape follow it. Defaults are today's drone.
  - Acceptance: Every non-default part makes at least one stat better and at least one worse. No part adds or removes an assist (a test compares the assist stack with and without each part). The default parts leave every stat as it is today. Every job can still be finished with every frame (the existing scripted runs pass with each frame fitted). Parts apply to the slot's drone only.
  - Out of scope: Parts beyond these three kinds, tuning the jobs for parts.

- [x] **27.5 The hangar**
  - Goal: The board's Garage opens the hangar: the drone on a turntable, with Paint, Lights, Decals, Parts and Upgrades, and every change shown live before it is applied.
  - Context: Replaces `ShopDialog` (the upgrades become the hangar's Upgrades tab, prices and rules unchanged). A SubViewport turntable of the drone with the slot's livery and parts; the player turns it with the right stick, the mouse or the arrow keys. Colours pick from a palette (no free colour wheel). Parts and upgrades show stat bars with the change highlighted before buying. The name is typed on keys, or picked from a list of names on a pad. Locked items show their price or their achievement (27.3). Works by pad alone, as Epic 23 requires, and at 960x720 and 1920x1080.
  - Acceptance: Changing a colour, light, decal or part updates the turntable at once; leaving without applying keeps the old livery. Applying writes the slot (27.1). Stat bars show the change of a part before it is fitted. Every control is reachable by pad, keys and mouse, and B or Esc backs out. Nothing overlaps at either size. The old shop's tests pass against the Upgrades tab.
  - Out of scope: Sharing liveries between players.

- [ ] **27.6 A livery for every fleet drone**
  - Goal: In fleet jobs each drone flies its own slot's livery and parts, and the hangar sets each one up.
  - Context: The hangar has a slot picker (your drone, then Fleet 1, Fleet 2, …, as many as the largest fleet; slots past the fleet you have reached are shown locked until the fleet is first flown). Fleet jobs build each drone from its slot. The fleet command view (`scripts/fleet/command_view.gd`) marks each drone's ring and name in its light colour, so the player can tell them apart, and a "copy to all" sets every fleet slot from the current one.
  - Acceptance: In a fleet job, drone N wears slot N's livery and flies with slot N's parts (a test checks materials and stats per drone). The command view's ring for each drone is in its light colour. "Copy to all" copies the livery and parts but leaves names. Slot 0 never changes a fleet drone.
  - Out of scope: Assigning crew pilots to drones by livery.

- [ ] **27.7 The crew notice**
  - Goal: The ride is part of the game's people: the crew comment on new paint and parts, and the drone's name shows where the player's name does.
  - Context: New bark events (`new_livery`, `new_part`), said the next time the board opens, by a living crew member, in each character's voice in `data/dialogue/`. Nala, the mechanic, has lines about parts. The drone's name shows on the results screen and in the flight HUD's job panel. Lines are respectful, with no pronouns for characters, as Epics 25 and 26 require.
  - Acceptance: After a livery change, the next board says a `new_livery` line once; after a part change, a `new_part` line, by Nala when Nala is alive. No line plays for the dead. The drone's name shows on results and in the HUD, and a drone with no name shows none. Every new line fits the radio at both sizes (26.4's test).
  - Out of scope: Voice audio beyond the existing babble.
