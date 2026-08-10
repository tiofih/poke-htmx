-- 0023: progressão por membro do time — XP/nível (D2-A). Idempotente; sem truncate.
-- A chave é o id do membro (estável à evolução D2-B); remoção do membro limpa o progresso.

CREATE TABLE IF NOT EXISTS team_pokemon_progress (
  team_pokemon_id INTEGER PRIMARY KEY REFERENCES team_pokemons(id) ON DELETE CASCADE,
  level INTEGER NOT NULL DEFAULT 1,
  xp INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);