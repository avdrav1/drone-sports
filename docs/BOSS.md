# Jaisalmer: Ravana

The final job. A rogue drone foundry that captures every drone it touches and builds itself bigger. You do not destroy it. You fly into it and switch it off.

## What it is

Ravana is an automated factory station that was supposed to build drones for the leagues. It kept building, started collecting, and now hangs over the city as a sphere a kilometer across: thousands of captured drones locked together into a shell around a core. Everything it takes becomes part of it. Some of the drones in the shell are ones your crew lost.

The player knows it as Ravana, after the ten-headed king of Lanka in the Ramayana, and the captured drones locked into its shell as Ravana's heads. The HUD and the controls say "heads" without a count; the fight has as many as it has. In code it keeps its internal name (`LatticeFight`, `data/boss/lattice.tres`).

It never speaks in the first person. Its lines are a chorus: short, flat, plural. "We are more now." "Your spotter's drone flies well for us."

## Shape language

- A sphere built from smaller units, so the surface reads as a grid of drones at a distance and as individual captured machines up close.
- One seam runs around it: the assembly trench, where new units are fitted. The trench is the only way in.
- The core is a single, old-fashioned override port behind a shutter. The port is small on purpose. Reaching it and holding still beside it is a flying problem, not a shooting problem.
- Nothing on it is organic. No faces, no eyes, no flesh. It is a machine, so it can be disabled and nobody dies.

The name comes from the Ramayana, and the namesake is treated with respect: Ravana is a formidable king, never a joke. The machine itself is original design. It borrows the feeling of a collective that absorbs you and the feeling of a run down a trench into a vulnerable core; it does not borrow any silhouette or design from existing games, films or other franchises.

## The fight

Three phases, one job, Act 5 preset (all assists off, command layer on). Every skill in the game gets used once.

| Phase | What you do | Which skill it tests | What can go wrong |
| --- | --- | --- | --- |
| 1. Reclaim | Direct your fleet to tag captured drones on the shell with override pucks. Each tagged head drops out of the shell and rejoins your fleet. Open a gap big enough to enter. | Fleet command (6.2), racing lines (3.x) | Captured drones fight back by disabling yours. A disabled fleet drone is recaptured and the gap closes. |
| 2. The trench | Fly your own drone through the assembly trench to the core shutter while the shell tries to close around you. Your crew calls the turns. | Raw flight, no assists (1.x) | Contact with the shell is a strike on whichever crew member is calling. Sanjaya and Bhima are in the field for this job. |
| 3. Override | Hold station inside a one-meter sphere at the override port for 10 seconds while Ravana shakes and gusts. Graded like an inspection hold. | Station keeping with no assists (1.5, 1.7, 4.4) | Drift out of the sphere and the timer resets. The swarm closes the trench behind you after 60 seconds. |

When the override lands, Ravana powers down section by section, the shell loosens, and every captured drone falls free. The ones that belonged to your crew come home. Dead crew members do not.

## Stakes

- The job is tagged `lethal`. Strikes kill. The launch dialog says so.
- The job requires Sanjaya (callouts) and at least two living crew tagged `can_fly` for the fleet. If you do not have them, the job board shows Ravana as unreachable with the reason. There is no alternate route.
- No retry from checkpoint. Fail and you restart the job, with any new injuries kept.

## Disabling the boss (the feature, not the fight)

`data/boss/lattice.tres` has `enabled: bool`. When false, the job never appears on the board, the Act 5 story ends after the fleet final from 6.4, and no boss assets load. This is the one place a whole tier can be switched off in data, so a demo or a kid-safe build can ship without it.

## Open questions

- [ ] Does Ravana have a reason, or is it just a runaway loop? A reason makes it sadder; a loop keeps it a machine.
- [ ] Should the override port move between attempts so the fight cannot be memorized?
- [ ] After the shutdown, is there an epilogue job flying the freed drones home?
