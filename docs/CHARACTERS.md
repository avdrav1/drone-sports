# Jaisalmer: Characters

The crew is the heart of the story. They are small, round, expressive, and they can die. Every death is the player's fault and the game says so.

## Rules

1. The player never kills anyone. The player can fail to protect someone.
2. Death is never random. A character is only at risk on a job that declares it, in a marked zone, after a visible warning. Two strikes: injured first, dead second.
3. Death is permanent and changes the game: lines, team offers, available jobs, the roster you can fly in fleet mode.
4. Characters are data. Roster, portraits, and lines live in `data/characters/` and `data/dialogue/`; no character is hard-coded in a scene.
5. Cute is a shape language, not a species. Round bodies, big eyes, two or three colors each, readable at 64 px. Species is an open question; placeholder art is colored shapes.

## Cast

| Id | Name | Role | Where they stand on a job | Risk | Named for |
| --- | --- | --- | --- | --- | --- |
| `arjuna` | Arjuna | Rookie pilot, the default player avatar | In the pilot chair | Never (the player) | The student archer every teacher wanted to train |
| `sanjaya` | Sanjaya | Spotter. Calls gates, marks, and hazards over comms | On the course, near the hardest gate | High | The one who saw the whole battle from afar and told it |
| `nala` | Nala | Mechanic. Repairs, sells upgrades, complains | In the van; near the building on demolition runs | Medium | The engineer who bridged the sea to Lanka |
| `bhima` | Bhima | Demolition foreman. Runs the salvage crew, calls the collapse | At the base of the building | High on demolition runs | The strongest of the five brothers |
| `sushena` | Sushena | Medic. The one you are looking for on search and rescue | Lost in the weather, timer running | High on rescue jobs | The healer who sent for the life-giving herb |
| `drona` | Drona | The scout who recruits you. Story voice | Never in the field | None | The teacher who found and trained the great archers |

Every name comes from the Ramayana or the Mahabharata and echoes the character's job; the CREW page (or, for a pilot with no CREW row, their pilot card) shows each "named for" line. The namesakes are treated with respect: no line mocks a namesake, and no deity is played for laughs. The ids are the code's keys (saves, jobs, file names); a save from before the rename is carried over to them on load.

Three more pilot avatars (so "play as" means a choice) are data beside Arjuna: Abhimanyu (`abhimanyu`, the young warrior who charged straight in), Jatayu (`jatayu`, the great bird who rode the high winds) and Hanuman (`hanuman`, who leapt the ocean to Lanka). Each avatar is a portrait, a voice-line set, and an edge, never a different flight model. An edge is data on the character: steps on the drone's exported stats (thrust, drag, flight time) and settings on the assists in front of the mixer (a higher governor cap, a faster climb). It never adds or removes an assist, and a setting for an assist the act has already removed does nothing.

## Strike system

- A job declares `crew_in_field: [sanjaya, bhima]` (Sanjaya and Bhima) and places a `HazardZone` for each.
- Entering a zone at speed, debris landing in it, or a rescue timer expiring is a strike. The HUD flashes the character's portrait one second before it lands, so the player always had a chance.
- First strike: injured. The character is benched for the next two jobs and their lines change. The results screen shows it.
- Second strike while injured, or a strike on a job tagged `lethal`: dead. Confirmation dialog before launching any job with an injured crew member in the field.
- Dead characters stay on the roster, greyed out, with a memorial line on the job board.

## What changes when someone dies

| If this character dies | Consequence |
| --- | --- |
| Sanjaya | No gate callouts. Races lose the split-delta HUD until a new spotter is recruited. |
| Nala | Shop closes for three jobs. Upgrades cost 25 percent more afterward. |
| Bhima | Salvage faction stops offering jobs. Demolition runs are locked out of this playthrough. |
| Sushena | City services faction stops offering jobs. |
| Drona | Cannot die. |

## What each crew member brings

Each support crew member carries a perk (`Character.perk`, Story 19.4), on while they are fit to work: off while benched, gone for good once dead. Systems ask `Perks.amount(kind)` and never name a character; two crew with the same kind add up.

| Crew | Kind | Name | Perk |
| --- | --- | --- | --- |
| Drona | `reputation` | good word | +25 percent reputation from every job |
| Sanjaya | `guidance` | spotting | Route guidance one step better on every job |
| Nala | `price` | trade prices | Garage prices 20 percent lower |
| Bhima | `pay` | site rates | +15 percent pay on every job |
| Sushena | `recovery` | quick patch-ups | An injury benches for one job instead of two (not Sushena's own) |

The CREW page shows each perk under its owner's status: struck through with the jobs left while benched, "No more ..." once dead. The results screen names each bonus paid and the perk an injury switches off, and the confirmation before launching with injured crew in the field names each perk a death would take.

## Open questions

- [ ] Species: animals, robots, something new? Decide before any art is commissioned.
- [ ] Should there be a rookie mode where strikes injure but never kill?
- [x] Do crew members ever fly drones themselves (Epic 6), and does a dead crew member shrink the fleet? Yes to both: crew tagged `can_fly` (Arjuna, Sanjaya, Nala, Sushena) each fly one fleet drone under autopilot, and a death takes that drone out of every fleet job (Story 7.7).
