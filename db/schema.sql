-- frozen_string_literal: true
-- Schema do banco de dados (sem auto-criar no boot; aplicado via `rake db:setup`).

CREATE TABLE IF NOT EXISTS team_pokemons (
  id SERIAL PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  sprite TEXT NOT NULL,
  number INTEGER NOT NULL,
  slot INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);