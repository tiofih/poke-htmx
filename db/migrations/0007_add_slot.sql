-- 0007: montagem de times — slot de posição + unicidade (sem duplicados).
-- Idempotente; trunca dados antigos (não têm slot/unicidade válidos).

TRUNCATE team_pokemons CASCADE;
ALTER TABLE team_pokemons ADD COLUMN IF NOT EXISTS slot INTEGER NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_team_pokemons_user_number ON team_pokemons (user_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS idx_team_pokemons_user_slot ON team_pokemons (user_id, slot);