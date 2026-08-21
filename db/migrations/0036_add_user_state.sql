-- 0036: J1 - tela de entrada da jornada (marcador persistido por usuario).
-- Idempotente; sem truncate.

CREATE TABLE IF NOT EXISTS user_state (
  user_id TEXT PRIMARY KEY,
  journey_started BOOLEAN NOT NULL DEFAULT false
);
