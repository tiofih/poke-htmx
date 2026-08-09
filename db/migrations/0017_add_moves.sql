-- 0017: pagina de gerenciamento de time — golpes escolhidos por Pokemon (A3/RF-17).
-- Idempotente; sem truncate (default '{}' cobre as linhas existentes).

ALTER TABLE team_pokemons ADD COLUMN IF NOT EXISTS moves TEXT[] NOT NULL DEFAULT '{}';