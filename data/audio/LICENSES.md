# Audio sources and licences

Every audio file under `data/audio/` and `data/music/` is listed here (music by its path from `data/audio/`). Two sources only:

- **generated**: made by `tools/sfx/` or `tools/music/` from a checked-in script; ours, no licence needed.
- **CC0**: public-domain recordings; the source URL is recorded so it can be checked.

`tests/test_sfx.gd` fails if a file is missing from this table or its licence is anything else.

| File | Source | Licence |
| --- | --- | --- |
| `generated/drone_hum.wav` | `tools/sfx/generate.py` | generated |
| `generated/drone_wash.wav` | `tools/sfx/generate.py` | generated |
| `generated/drone_impact_1.wav` | `tools/sfx/generate.py` | generated |
| `generated/drone_impact_2.wav` | `tools/sfx/generate.py` | generated |
| `generated/drone_impact_3.wav` | `tools/sfx/generate.py` | generated |
| `generated/flight_recovered.wav` | `tools/sfx/generate.py` | generated |
| `generated/flight_low_battery.wav` | `tools/sfx/generate.py` | generated |
| `generated/flight_guard.wav` | `tools/sfx/generate.py` | generated |
| `generated/flight_brake.wav` | `tools/sfx/generate.py` | generated |
| `generated/camera_view.wav` | `tools/sfx/generate.py` | generated |
| `generated/job_briefing.wav` | `tools/sfx/generate.py` | generated |
| `generated/job_countdown.wav` | `tools/sfx/generate.py` | generated |
| `generated/job_go.wav` | `tools/sfx/generate.py` | generated |
| `generated/job_gate.wav` | `tools/sfx/generate.py` | generated |
| `generated/job_hold_tick.wav` | `tools/sfx/generate.py` | generated |
| `generated/job_hold_done.wav` | `tools/sfx/generate.py` | generated |
| `generated/job_complete.wav` | `tools/sfx/generate.py` | generated |
| `generated/job_fail.wav` | `tools/sfx/generate.py` | generated |
| `generated/job_payout.wav` | `tools/sfx/generate.py` | generated |
| `generated/hazard_warning.wav` | `tools/sfx/generate.py` | generated |
| `generated/hazard_strike.wav` | `tools/sfx/generate.py` | generated |
| `generated/ui_click.wav` | `tools/sfx/generate.py` | generated |
| `generated/ui_focus.wav` | `tools/sfx/generate.py` | generated |
| `generated/ui_confirm.wav` | `tools/sfx/generate.py` | generated |
| `generated/city_hum.wav` | `tools/sfx/generate.py` | generated |
| `generated/desert_wind.wav` | `tools/sfx/generate.py` | generated |
| `generated/room_tone.wav` | `tools/sfx/generate.py` | generated |
| `generated/debris_impact_1.wav` | `tools/sfx/generate.py` | generated |
| `generated/debris_impact_2.wav` | `tools/sfx/generate.py` | generated |
| `generated/debris_impact_3.wav` | `tools/sfx/generate.py` | generated |
| `generated/crew_chirp.wav` | `tools/sfx/generate.py` | generated |
| `generated/lattice_tone.wav` | `tools/sfx/generate.py` | generated |
| `generated/lattice_drone.wav` | `tools/sfx/generate.py` | generated |
| `generated/lattice_power_down.wav` | `tools/sfx/generate.py` | generated |
| `generated/bed_intro.wav` | `tools/sfx/generate.py` | generated |
| `generated/bed_recruited.wav` | `tools/sfx/generate.py` | generated |
| `generated/city_hum_muffled.wav` | `tools/sfx/generate.py` (`city_hum` low-passed for snow's hush) | generated |
| `generated/desert_wind_muffled.wav` | `tools/sfx/generate.py` (`desert_wind` low-passed for snow's hush) | generated |
| `cc0/rain_loop.ogg` | "Rain (loopable)" by Ylmir, `1.ogg` at 8 s, 6 s crossfaded loop: https://opengameart.org/content/rain-loopable | CC0 |
| `cc0/rain_roof_loop.ogg` | "Rain in the Gutter Loop" by Ogrebane, at 20 s, 6 s crossfaded loop: https://opengameart.org/content/rain-gutter-loop | CC0 |
| `cc0/wind_loop.ogg` | "wind whoosh loop" by SketchMan3 (from JaggedStone's CC0 "Loopable Dungeon Ambience"), whole loop: https://opengameart.org/content/wind-whoosh-loop | CC0 |
| `cc0/wind_loop_muffled.ogg` | `cc0/wind_loop.ogg` low-passed (500 Hz, twice) for snow's hush; same source: https://opengameart.org/content/wind-whoosh-loop | CC0 |
| `cc0/thunder_1.ogg` | "100 CC0 SFX #2" by rubberduck, `sfx100v2_thunder_01.ogg` from 0.5 s: https://opengameart.org/content/100-cc0-sfx-2 | CC0 |
| `cc0/thunder_2.ogg` | "Rain + Long Thunder" by WuxiaScrub, `rain-thunder.ogg` 20.8 to 31.8 s: https://opengameart.org/content/rain-long-thunder | CC0 |
| `cc0/thunder_3.ogg` | "Rain + Long Thunder" by WuxiaScrub, `rain-thunder.ogg` 27.5 to 35.5 s, low-passed (900 Hz) for a distant roll: https://opengameart.org/content/rain-long-thunder | CC0 |
| `../music/placeholder_tonic.ogg` | `tools/music/generate.py` | generated |
| `generated/pitches.json` | `tools/sfx/generate.py` (base pitches of the tuned sounds, not audio) | generated |
| `../music/demo_demo.ogg` | `tools/music/generate.py` | generated |
| `../music/manifest.json` | `tools/music/generate.py` (the key, instruments and scores, not audio) | generated |
| `../music/mantra_mantra_voice.ogg` | `tools/music/generate.py` | generated |
| `../music/mantra_mantra_lead.ogg` | `tools/music/generate.py` | generated |
| `../music/mantra_mantra_tanpura.ogg` | `tools/music/generate.py` | generated |
| `../music/act_1_drone.ogg` | `tools/music/generate.py` | generated |
| `../music/act_1_pad.ogg` | `tools/music/generate.py` | generated |
| `../music/act_1_arp.ogg` | `tools/music/generate.py` | generated |
| `../music/act_1_bass.ogg` | `tools/music/generate.py` | generated |
| `../music/act_1_kick.ogg` | `tools/music/generate.py` | generated |
| `../music/act_1_clap.ogg` | `tools/music/generate.py` | generated |
| `../music/act_1_mantra_lead.ogg` | `tools/music/generate.py` | generated |
