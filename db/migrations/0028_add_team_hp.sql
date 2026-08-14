-- 0028: HP persistente por membro (Eco-2 — Poke Center). Idempotente; sem truncate.
-- hp_max/hp_current = 0 significa "nunca batalhou" (HP cheio); 0029+ não precisa.

ALTER TABLE team_pokemon_progress ADD COLUMN IF NOT EXISTS hp_max INTEGER NOT NULL DEFAULT 0;
ALTER TABLE team_pokemon_progress ADD COLUMN IF NOT EXISTS hp_current INTEGER NOT NULL DEFAULT 0;
