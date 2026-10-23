-- Godot v22 uses its own protocol; preserve the Canvas rooms and their RLS.
-- The directory previously accepted only the eight original fighters.
alter table public.svf_rooms drop constraint svf_rooms_character_check;
alter table public.svf_rooms add constraint svf_rooms_character_check check
  (character in ('adriano','marcelo','rafael','gustavo','gelton','marcelino','marcos',
                'tais','luciana','joao','khauany','dienes','ruan'));
notify pgrst, 'reload schema';
