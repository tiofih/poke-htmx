-- 0031: Eco-4-B — item atribuido por membro (estrategia selecionavel pre-batalha).
-- Idempotente; sem truncate (nullable cobre as linhas existentes).

ALTER TABLE team_pokemons ADD COLUMN IF NOT EXISTS assigned_item TEXT;