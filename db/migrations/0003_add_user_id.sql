-- 0003: equipe por usuário — adiciona user_id. Idempotente; trunca dados antigos
-- (registros sem dono) e indexa a coluna para as consultas por usuário.

TRUNCATE team_pokemons;
ALTER TABLE team_pokemons ADD COLUMN IF NOT EXISTS user_id TEXT NOT NULL;
CREATE INDEX IF NOT EXISTS idx_team_pokemons_user_id ON team_pokemons (user_id);
