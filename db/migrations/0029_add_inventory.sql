-- 0029: inventario do Poke Mart (Eco-3). Idempotente; sem truncate.
-- 1 linha por (user_id, item_name); quantidade soma via upsert (RF-05).

CREATE TABLE IF NOT EXISTS inventory (
  user_id TEXT NOT NULL,
  item_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, item_name)
);