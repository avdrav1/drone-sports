# Jaisalmer: The Four

Brahma, Vishnu, Shiva and Krishna carry the story's frame and shape how the career is played. They are not crew, not pilots, not enemies and not rewards. This file is the design for them; Epic 30 in `docs/BACKLOG.md` builds it.

Status: proposal. Nothing here is built until the owner says go, and nothing here ships before the review in "Respect" below.

## Why these four fit this game

The game already stands inside the epics. The player is Arjuna, the spotter is Sanjaya, and the boss is Ravana. Each of the four has a real bond with one of them:

| Who | Their bond with the cast | What it gives the game |
| --- | --- | --- |
| Brahma | Granted Ravana the boon that no god, demon or spirit could unmake him. Ravana, too proud to fear them, left humans off the list. | The rule of the final fight: no machine can switch Ravana off, only a human hand on the sticks. |
| Vishnu | The preserver. His avatar Rama ended Ravana's reign; his avatar Krishna drove Arjuna's chariot. | The crew-protection arc: Arjuna stops chasing scores and starts keeping people alive. |
| Shiva | Destruction that makes room for the new. Ravana was his devotee, and tried to lift Mount Kailash; Shiva held it down with one toe. | Letting go of assists. And the lesson of the override hold: stillness and a light touch beat raw force. |
| Krishna | Arjuna's charioteer, who vowed not to take up a weapon and guided instead. Sanjaya narrated their talk before the battle. | The guide who hands Arjuna the reins, then teaches him to command without fighting: the fleet tier. |

The career already runs through creation, preservation and dissolution, and the charioteer rides through all of it:

| Act | Whose thread leads | What the player is learning |
| --- | --- | --- |
| 1. The game | Brahma | Being made: a drone, a city, a pilot |
| 2–3. Real jobs | Vishnu | Keeping the crew safe as the guards come off |
| 4. Specialist | Shiva | Letting go: full throttle, no governor, raw flight |
| 5. Fleet | Krishna | Guiding many instead of flying one |
| Throughout | Krishna | Guidance that steps back as the pilot grows |

## Brahma: the maker, and the boon

**Story.** Act 1 opens on making: the home game, the city of Jaisalmer, the first drone. Brahma's temple at Pushkar is in Rajasthan, Jaisalmer's own state, and the city's Brahma shrine looks toward it.

The boon is the hinge of the ending. The foundry that became Ravana was built so that no drone, no assist and no autopilot could ever stop it. Its makers named it for the king whose boon left out the one thing he scorned. The briefing for the final job says so plainly, and it is why the trench and the override are flown with every assist off: they are the parts only a human can do.

**Play.** The vow of making: on jobs that allow it, plan the route on the map before launch, then fly the path you made. Kept when the drone passes your points in order. Garage upgrades are framed as making too, but they stay what they are: stat changes, never assists (rule 5).

## Vishnu: the preserver

**Story.** Acts 2 and 3 are about the crew. Collision guard and altitude hold were the drone preserving itself; when they come off, preserving the crew becomes the pilot's job.

**Play.**
- The vow of keeping: on a job with crew in the field, "No one is struck." Kept when the job ends with no strike on anyone.
- The hazard warning (the one-second flash before a strike, `CrewWarning`) takes the chakra as its ring. The warning's timing and rules do not change (rule 7).

## Shiva: letting go

**Story.** Act 4 is the shedding. Each promotion that removes an assist gets a short scene at the act gate that names what is being let go and what it unlocks (the assist table in CLAUDE.md). Demolition runs, where Bhima's crew brings a building down so the city can build again, belong to this thread.

**Play.** The vow of letting go: fly this job with the next act's assist already off. Kept when the job is completed that way. It uses the existing assist settings, so it is exactly what a sim player can already do, given a meaning (rules 2 and 5 hold: no assist is added, the physics never change).

## Krishna: the charioteer

**Story.** Krishna rides with Arjuna the whole game. His voice is never heard directly in flight; Sanjaya relays him, as Sanjaya relayed him in the epic. Early on, full route guidance is the charioteer showing the road; as the guidance steps down (full, next leg, none) he hands over the reins.

Act 5 is his. The fleet tier is the way he fought: guiding, not striking. Before the final job, Arjuna hesitates, as he did before the battle, because Ravana's job is lethal for the crew in the field. Krishna's counsel, relayed by Sanjaya, is the launch confirmation for that job. It speaks to duty, to acting without clinging to the outcome, and to the crew who stand with you. It changes with what the player has done: the vows kept, the crew lost. The choice to launch stays with the player.

**Play.** The vow of guiding: on a fleet job, finish without dropping into a drone. Kept when the job completes with the command layer only.

## Vows

A vow is an optional promise the player makes in the launch dialog, at most one per job, offered only on jobs whose data lists it. Vows are the player's own conduct. They are not prayers, offerings or purchases, and a god never "grants" anything in exchange.

| Vow | Thread | Kept when | Offered on |
| --- | --- | --- | --- |
| Making | Brahma | The drone passes the planned points in order | Jobs with route planning (Act 4 on) |
| Keeping | Vishnu | No strike on any crew member | Jobs with `crew_in_field` |
| Letting go | Shiva | Completed with the next act's assist off | Jobs before Act 5 whose next act removes an assist |
| Guiding | Krishna | Completed without dropping into a drone | Fleet jobs |

What a kept vow does:
- It is recorded in the save, per thread.
- It lights a lamp at that god's shrine in the city (below). The lamps are how the player sees their path.
- It shapes the story: the act-gate scenes and Krishna's counsel acknowledge what was kept.
- It never changes pay, reputation, grade, unlocks or physics. A broken vow is only a vow not kept: the results screen says so quietly, with no penalty and no scolding line.

## The shrines

Four rooftop shrines stand in the city, one for each, marked by symbol. Each has lamps that light as that thread's vows are kept. They are visible from the air and on the map, and placed on plazas where no course, gate or hazard sits near them. Drones never collide with or damage them, and nothing in the game can.

## How they appear

- Never in the crew's cartoon shape language, never with expressions, emotes, babble or barks.
- Shown through symbols, colour, place and music:

| | Symbols | Colour | Music motif |
| --- | --- | --- | --- |
| Brahma | Lotus, the four Vedas | Gold | A rising line, slow |
| Vishnu | Conch, chakra | Deep blue | A held, sheltering chord |
| Shiva | Trident, crescent moon, damaru | Ash white and indigo | The damaru's pulse |
| Krishna | Flute, peacock feather | Dark blue and peacock green | A flute line, in the song's key |

- Symbols are original drawings, not copies of any temple art, poster or other game's iconography.
- Krishna's counsel is text and Sanjaya's voice, not a portrayed Krishna.

## Respect

These are gods worshipped by more than a billion people today, not only figures in a story. The rules:

1. No god is ever at risk: never in a `HazardZone`, never struck, injured, killed, captured, disabled or defeated, and never part of Ravana.
2. No god is a playable pilot, a crew member, a perk, a shop item, an unlock or a currency. No god is bought, earned or upgraded.
3. No god is played for laughs: no jokes, emotes, gags or cartoon expressions, in any line or scene.
4. No invented scripture. Lines are original and in the spirit of the texts, or a paraphrase spoken by Sanjaya. Nothing is presented as a quotation unless it is one, from a translation the project may use.
5. Shrines are never collided with, damaged, used as gates, or placed in a job's path.
6. Before release, someone who practises the tradition reviews every line, symbol and scene. The epic's last story waits for that review.

CLAUDE.md is the owner's to edit. A rule worth adding there, beside rule 9:

> 10. Brahma, Vishnu, Shiva and Krishna frame the story and the vows (`docs/DEITIES.md`). They are data in `data/deities/`, have no status in the save beyond vows kept, and are never at risk, playable, sold, earned, mocked or shown in the crew's cartoon style.

## When the boss is switched off

When `data/boss/lattice.tres` has `enabled = false`, nothing about Ravana loads: no boon in any briefing, no counsel scene for the final job. Krishna's counsel then plays before the fleet final from 6.4, without any mention of Ravana. Everything else (vows, shrines, act gates) is unchanged.

## Open questions

- [ ] Who reviews the lines and symbols, and when?
- [ ] Do the four have voices of their own anywhere, or only symbols, music and Sanjaya's relay? (This proposal: only the relay.)
- [ ] Should the shrines be visitable in free flight (a slow, respectful pass), or seen only?
- [ ] Does the act-1 opening name Brahma, or show only his symbol until the player first sees the shrine?
