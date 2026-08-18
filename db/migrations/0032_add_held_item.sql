-- 0032: Eco-4-C — seguraveis/hold items (1 slot por membro, coluna separada de assigned_item).
-- Idempotente; sem truncate (nullable cobre as linhas existentes).

ALTER TABLE team_pokemons ADD COLUMN IF NOT EXISTS held_item TEXT;