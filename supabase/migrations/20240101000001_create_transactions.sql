CREATE TABLE transactions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  type TEXT NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  note TEXT DEFAULT ''::text,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all for authenticated users"
  ON transactions
  FOR ALL
  USING (true)
  WITH CHECK (true);
