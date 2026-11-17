# Pop the Planet

Final name, picked 2026-11-17 after a first Steam and WIPO search (no identical game or mark). A professional trademark search is still due before the Steam page. The repo folder keeps its old name.

## Pitch

Pop all the bubble wrap in the world: an endless sheet, a counter of the 10,000,000,000,000 bubbles left on Earth, and tools that grow from a finger to a fleet of steamrollers. An absurd incremental game built for short viral clips: the pop (sound, bulge, flecks) must feel good from the very first click.

- Solo first. Online co-op only if the hook works.
- Target: Steam (PC/Mac, mouse). The Steam page and TikTok clips come early, before the game is finished.

## Prototype (current)

Question: is popping satisfying, and does the upgrade loop pull you forward?

Done: endless hex sheet, finger click (press squeezes, release bursts), bigger thumb (radius), rolling pin (hold and drag), steamrollers (drive outward forever, wider drums), seven producer tiers that pop elsewhere on Earth (elephants to pulling the Moon closer), world counter that stops at the world total, zoom out to the bubble-wrapped globe when a producer tier joins in, combo multiplier fed by popping by hand (rolling feeds it fastest), golden bubbles (lucky lump or frenzy), save.

## How it is built

- Godot 4.7, GDScript, Forward+. Everything is built in code from `scenes/main.tscn`.
- `SheetData`: the sheet as data, hex rows split in 32x32 chunks, one byte per bubble, a chunk exists once one of its bubbles is popped. All pops go through `Game.pop_segment` (a capsule, or the nearest bubble when the radius is 0).
- `SheetView`: one MultiMesh per visible chunk, recycled while the camera moves. Instance custom data `(popped, pop time)` drives `shaders/bubble.gdshader`; the global shader uniforms `pop_clock`, `pop_hover` and `pop_press` (squeeze while the button is held) come from `Game`.
- `SheetView` hides its chunks above `CHUNK_MAX_HEIGHT`; the floor shader (`shaders/sheet_floor.gdshader`) then paints the bubbles. Popped bubbles are not shown from that high. Shader colors are linear: use `source_color` uniforms for sRGB values.
- `Cinematic`: the zoom out timeline (climb, cut to `Globe`, hold, dive, descend), driven by `Game` each frame. A click skips, F8 replays it (dev, for clips). `Globe` sits far below the sheet with its own camera; one spark per producer unit.
- `Combo`: a meter fed by hand pops in `Game`, its multiplier applies to every pop (hand, steamrollers, producers). `GoldenBubble`: spawns on screen now and then; only a hand pop claims it (`Game.claim_golden`), a steamroller just crushes it.
- `Economy`: prices and upgrades, data in constants. One popped bubble = one pop to spend; spending never lowers the popped counter. `PRODUCERS` add pops per second without touching `SheetData` (10^13 bubbles cannot be stored).
- Pacing: `godot --headless --path . res://tools/balance.tscn` simulates a greedy player on the real `Economy` and prints when each upgrade is first bought. Target, for a player who never combos: first steamroller within minutes, Earth emptied in about 2.5 h (guarded by `test_pacing_stays_in_target`). F10 in game cycles time x1/x10/x100 for testing.
- `PopFx`: flecks, sounds (rate-limited, plus a `crackle.wav` loop faded in by the visible pop rate) and shake, only for pops the camera sees.
- Sounds are synthesized by `python3 tools/generate_sounds.py` into `assets/sounds/`.
- Save: `user://save.dat`, zstd-compressed `store_var`. No compatibility during development: bump `Game.SAVE_VERSION` and older saves start over. F9 resets the save.

## Tests and captures

- Headless tests after any gameplay change: `godot --headless --path . res://tests/run_tests.tscn` (non-zero exit = failure).
- The headless renderer keeps no MultiMesh data: check looks with a screenshot, `godot --path . res://tools/capture.tscn -- --pops 25 --out /tmp/shot.png` (options at the top of `tools/capture.gd`). It opens a window for about a second; never open the Godot editor.
- Skills in `.claude/skills/` are third-party copies (see `THIRD_PARTY.md`): `godot-3d-essentials`, `godot-shaders`, `godot-ui-control` with `game-ui-ux`, `godot-gdscript-headless-testing`, `game-feel`, `input-systems`. Where they disagree with this file, this file wins.
