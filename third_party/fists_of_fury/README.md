# Fists of Fury integration

Original: https://github.com/nicolasbize/fists-of-fury-course
Pinned upstream commit: `0f353aea614cf57e43fb3776667c26dd3ce7714c`.
Copyright (c) 2025 Nicolas Bize, MIT; see LICENSE in this directory.

The campaign integrates adaptations of Player.handle_input/set_heading,
Player.reserve_slot/free_slot, BasicEnemy.goto_melee_position/prep attack,
and Character hurt/fall/ground/recover and Collectible flight behavior.
Runtime: scripts/story/fury_combat.gd, story_enemy_motion.gd,
story_simulation.gd and story_objects.gd.

The adapter keeps the existing 120 Hz integer simulation, authored full-body
character drawings, power system, snapshots and browser/online shell.
Wall-clock timers, random attack shuffling and Node reference ownership were
replaced with serialized counters and stable integer IDs for rollback.
No upstream artwork, music or fonts are redistributed.

This is an adaptation of the combat foundation, not the complete course game
repackaged. Knives/guns and the course's stage art are not imported. Heavy
furniture is destructible; chairs are kicked into projectiles at the real
contact frame. There is no furniture carry pose or human grapple in this version.
