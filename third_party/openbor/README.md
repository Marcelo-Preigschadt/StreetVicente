# OpenBOR routines used by the campaign prototype

Upstream: https://github.com/gonzalomvp/openbor
Branch: `v6330-fflns`
Pinned commit: `4c8677c2a747b13dbf0e2f9162509ac14a138c9c`
License: BSD-3-Clause; original notice preserved in `LICENSE` and the source files.

`openbor.c` and `openbor.h` are unmodified upstream source, retained for review.
They are not compiled or loaded by Godot and are not included in the Web package.

The GDScript adaptation is deliberately limited:

| Upstream routine | Godot adaptation |
| --- | --- |
| `testmove`, `common_trymove` | `OpenBorMotion`: bounds on the floor plane, separate X/Z obstacle checks, partial movement along an unblocked axis, and a final position update. Adds swept axis clipping and escape from old-save overlaps. |
| `adjust_grabposition` | `OpenBorCombat._try_grab`: midpoint alignment, then keep the obstructed participant fixed and move the other; fail if both placements are blocked. |
| `dograb`, `common_throw_wait`, `dothrow` | `OpenBorCombat`: stop both participants, link by serialized actor ID, release on the authored throw frame, unlink, and toss the victim as a damaging body projectile. |
| `normal_find_target`, `common_try_normalattack` | Campaign AI uses floor distance and attack range before selecting a prepared attack; local routing and a two-attacker limit are original campaign adaptations. |

The existing fixed-point `FighterModel`, authored character moves, powers,
renderer, hitstop, rollback serializer and campaign wave data remain in use.
The input/normal-chain adapter originated in the prior MIT Fists of Fury
adaptation; its notice remains in `third_party/fists_of_fury/`.
The updated normal chain is hit-confirmed and can cancel into authored powers.
This is not the full OpenBOR runtime, nor a port of the complete Final Fight LNS
game module. The latter was not obtained from the official MediaFire download.
No Final Fight LNS artwork, music, character definitions or stage scripts are
included.

Streets of Rage 4 is the visual/gameplay reference for the next presentation
pass. Its source and assets are not part of this adaptation.
