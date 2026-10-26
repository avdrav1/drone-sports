# Drone Sports: Game Vision

## The pitch

You are a gamer in a near future where drone piloting is the biggest sport and the best-paid trade on Earth. The game you play at home is secretly a tryout. A team scouts you, hands you a real drone, and you work your way up from solo jobs to running a fleet. One flight model runs the whole game. You start with every assist switched on and earn the right to fly without them.

Star Fox gives the feel. The Last Starfighter gives the plot. Ready Player One gives the world. A realistic drone sim gives the jobs.

## Where it comes from

| Source | What it contributes | What we leave behind |
| --- | --- | --- |
| Star Fox | Arcade flying, stylized ships, enemies that are machines | Nothing; it is the tutorial feel |
| The Last Starfighter | The home game is a tryout; being good gets you drafted | The real war. You are drafted into a sport and a trade |
| Ready Player One | A full economy inside the game world; fame and money from play | The dystopia and the treasure hunt |
| Drone flight sim | Realistic flight; stakes that come from the task itself (a collapse, a rescue) | The film-crew framing. The sim is the late-game job tier |

No real-world footage, no killing. Every enemy is a machine. The people in the game are your own crew, and they are the ones at risk.

## The world

Drones do most of the flying in this future, and people who can pilot them are stars. Three kinds of work pay:

- **Drone sports.** Racing, team capture, arena bouts against other drones. Televised, sponsored, bet on.
- **Drone work.** Demolitions, search and rescue, cargo, inspections. Dangerous, well paid, the setting for the best challenges.
- **Fleet command.** The top tier. You stop flying one drone and direct many.

Teams and factions own the drones. A league team wants trophies, a salvage crew wants the building down clean, the city wants its medic back. Your faction changes which jobs you see and which assists come off.

## The flight model

There is one drone physics model and it never changes. What changes is how much of it the game handles for you.

Assists are the progression. A rookie's drone holds altitude, levels itself, caps its speed, and refuses to fly into things. Each promotion strips one away because the job needs it gone. By the top tier you fly raw.

This keeps both audiences. Arcade players never meet a new rule set. Sim players can switch assists off from the start and take the harder grade.

| Assist | On by default until | What removing it unlocks |
| --- | --- | --- |
| Collision guard | Act 2 | Tight gaps, interior flying |
| Altitude hold | Act 3 | Dives, low passes, following terrain |
| Auto-level | Act 3 | Banked turns, knife-edge gaps |
| Speed governor | Act 4 | Full throttle, top speed, and the crashes that come with it |
| Battery and wind sim | Act 4 | Route planning, timing a pass to a gust |
| Single-drone view | Act 5 | Command layer for fleets |

## The crew

You play as a pilot and fly for a crew of small, round, expressive characters: a spotter on the course, a mechanic in the van, a foreman at the foot of a building, a medic lost in the weather. They talk you through every job. They are also the stakes. A job can put a crew member in the field, and a bad enough run hurts them. Twice, or once on a lethal job, and they die. Death is permanent and the game changes around it: lines, team offers, whole job tiers. See `docs/CHARACTERS.md` for the cast and the strike rules.

Death is never random. It only happens in a marked zone, after a visible warning, on a job that said so up front.

## The progression

1. **The game.** A drone racing game at home. All assists on. Enemies are robot drones. Your scores are being watched.
2. **The tryout.** A scout shows up. You fly a real drone in a sanctioned race. Same model, same assists, physical course, a contract at stake.
3. **Single drone, real jobs.** Contracts for your team. Collision guard comes off first, then altitude hold.
4. **Specialist.** Pick a faction and a discipline: racing, hazard work, rescue. Auto-level and the speed governor come off. A realistic drone, flown by hand, graded on the shot.
5. **Fleet.** Promoted off the sticks. Direct three, then ten, then fifty drones. Single-drone view gives way to a command layer.

Recruitment is the gate between acts. A team has to want you. Each promotion is also a permission: one less assist.

## Core loop and job types

Take a job, fly it, get graded, get paid, get noticed. Reputation unlocks better jobs and teams. Money buys upgrades, not promotions.

| Job type | The challenge | Who hires you |
| --- | --- | --- |
| Race | Gates, splits, other drones in your line | League teams |
| Demolition run | Fly through and out of a building as it comes down, foreman at the base | Salvage crews |
| Search and rescue | Find a target in bad weather before a timer runs out | City services |
| Inspection | Hold a tight orbit on a structure, no contact, full coverage | Contractors |
| Arena | Disable enemy drones, capture a point, protect a payload | League teams |

The demolition run is the signature job. Collision guard is off, the building is falling, and Bea is standing at the base of it.

The camera is a flying tool, not a mechanic: chase for racing, FPV for gaps, orbit for inspections, top-down for fleets. Nothing is graded on what the camera sees.

## The ending

The last job is the Lattice: a rogue drone foundry that captured every drone it touched and built itself into a sphere over the city, a shell of thousands of machines around a core. Some of those machines were your crew's. You do not destroy it. You command your fleet to reclaim drones and open a gap, fly the assembly trench with no assists while your crew calls the turns, and hold station at the override port long enough to switch it off. Every skill in the game gets used once. The job is lethal for the crew in the field, and it can be turned off in data for builds that do not want it. See `docs/BOSS.md`.

## What the game is not

- No real-world footage, nothing modeled on real strikes.
- You never kill anyone. You can fail to save someone. Enemies are machines; the only people at risk are your own crew, and only where the job says so.
- Not a military story. You serve a team or a crew, never an army.
- Not two games. No genre switch; the physics in act one are the physics in act five.
- Not a shooter at the end. The boss is disabled, not destroyed.

## Open questions

- [ ] Does the player learn the home game was a tryout, or is that the act-one twist?
- [ ] Which assists does the existing drone sim already have, and which need building?
- [ ] Is the fleet tier a different genre (RTS) or still flown from a lead drone?
- [ ] One faction per playthrough, or can you switch teams mid-career?
- [ ] Does all-assists-on feel like an arcade flyer, or just easy? Needs a prototype.
- [ ] Should there be a rookie mode where crew get hurt but never die?
