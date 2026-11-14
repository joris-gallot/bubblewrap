# Third-party skills

These skills are vendored, unmodified, from
[gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills)
(Apache-2.0, see `THIRD_PARTY_LICENSE` and `THIRD_PARTY_NOTICE`).

| Skill | Upstream commit |
|---|---|
| `godot-gdscript-headless-testing` | `c6ca6c41c839b68319ffc08430b99ab768debc32` |
| `game-feel` | `c6ca6c41c839b68319ffc08430b99ab768debc32` |
| `input-systems` | `c6ca6c41c839b68319ffc08430b99ab768debc32` |
| `godot-ui-control` | `c6ca6c41c839b68319ffc08430b99ab768debc32` |
| `game-ui-ux` | `c6ca6c41c839b68319ffc08430b99ab768debc32` |
| `godot-3d-essentials` | `c6ca6c41c839b68319ffc08430b99ab768debc32` |
| `godot-shaders` | `c6ca6c41c839b68319ffc08430b99ab768debc32` |

Notes:

- Upstream rewrites its skills often, so copies are pinned on purpose. To update one, re-download it from a newer commit and review the diff before committing.
- They mention sibling skills and helper scripts that were not vendored (`godot-nodes-scenes` and its `check_godot_project.py`, `physics-tuning`, `shader-programming`, `platformer`...). Ignore those references.
- Where a vendored skill and `AGENTS.md` disagree, `AGENTS.md` wins (for example, tests run through `tests/run_tests.tscn`, not a separate runner or a copied `test_animation_states.gd`, and screenshots are taken with `tools/capture.tscn`).
