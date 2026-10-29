# Drone Sports: Characters

The crew is the heart of the story. They are small, round, expressive, and they can die. Every death is the player's fault and the game says so.

## Rules

1. The player never kills anyone. The player can fail to protect someone.
2. Death is never random. A character is only at risk on a job that declares it, in a marked zone, after a visible warning. Two strikes: injured first, dead second.
3. Death is permanent and changes the game: lines, team offers, available jobs, the roster you can fly in fleet mode.
4. Characters are data. Roster, portraits, and lines live in `data/characters/` and `data/dialogue/`; no character is hard-coded in a scene.
5. Cute is a shape language, not a species. Round bodies, big eyes, two or three colors each, readable at 64 px. Species is an open question; placeholder art is colored shapes.

## Cast

| Id | Name | Role | Where they stand on a job | Risk |
| --- | --- | --- | --- | --- |
| `pip` | Pip | Rookie pilot, the default player avatar | In the pilot chair | Never (the player) |
| `marlo` | Marlo | Spotter. Calls gates, marks, and hazards over comms | On the course, near the hardest gate | High |
| `dot` | Dot | Mechanic. Repairs, sells upgrades, complains | In the van; near the building on demolition runs | Medium |
| `bea` | Bea | Demolition foreman. Runs the salvage crew, calls the collapse | At the base of the building | High on demolition runs |
| `ozzie` | Ozzie | Medic. The one you are looking for on search and rescue | Lost in the weather, timer running | High on rescue jobs |
| `rin` | Coach Rin | The scout who recruits you. Story voice | Never in the field | None |

Three more pilot avatars (so "play as" means a choice) can be added as data once Pip works. Each avatar is a portrait, a voice-line set, and an edge, never a different flight model. An edge is data on the character: steps on the drone's exported stats (thrust, drag, flight time) and settings on the assists in front of the mixer (a higher governor cap, a faster climb). It never adds or removes an assist, and a setting for an assist the act has already removed does nothing.

## Strike system

- A job declares `crew_in_field: [marlo, bea]` and places a `HazardZone` for each.
- Entering a zone at speed, debris landing in it, or a rescue timer expiring is a strike. The HUD flashes the character's portrait one second before it lands, so the player always had a chance.
- First strike: injured. The character is benched for the next two jobs and their lines change. The results screen shows it.
- Second strike while injured, or a strike on a job tagged `lethal`: dead. Confirmation dialog before launching any job with an injured crew member in the field.
- Dead characters stay on the roster, greyed out, with a memorial line on the job board.

## What changes when someone dies

| If this character dies | Consequence |
| --- | --- |
| Marlo | No gate callouts. Races lose the split-delta HUD until a new spotter is recruited. |
| Dot | Shop closes for three jobs. Upgrades cost 25 percent more afterward. |
| Bea | Salvage faction stops offering jobs. Demolition runs are locked out of this playthrough. |
| Ozzie | City services faction stops offering jobs. |
| Rin | Cannot die. |

## Open questions

- [ ] Species: animals, robots, something new? Decide before any art is commissioned.
- [ ] Should there be a rookie mode where strikes injure but never kill?
- [x] Do crew members ever fly drones themselves (Epic 6), and does a dead crew member shrink the fleet? Yes to both: crew tagged `can_fly` (Pip, Marlo, Dot, Ozzie) each fly one fleet drone under autopilot, and a death takes that drone out of every fleet job (Story 7.7).
