-- 0027: moeda pos-batalha (Eco-1). Idempotente; sem truncate.
-- Saldo por usuario: 1 linha por user_id (RF-05); balance soma via upsert.

CREATE TABLE IF NOT EXISTS wallet (
  user_id TEXT PRIMARY KEY,
  balance INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);