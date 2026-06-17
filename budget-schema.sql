-- ============================================
-- FAMILY BUDGET APP - Supabase Schema
-- Ariel & Paty · $300/week rolling budget
-- ============================================

-- 1. SETTINGS (presupuesto semanal y fecha de inicio)
CREATE TABLE IF NOT EXISTS settings (
  id INTEGER PRIMARY KEY DEFAULT 1,
  weekly_budget NUMERIC(10,2) NOT NULL DEFAULT 300.00,
  budget_start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  CONSTRAINT single_row CHECK (id = 1)
);

INSERT INTO settings (id, weekly_budget, budget_start_date)
VALUES (1, 300.00, '2025-01-06') -- Cambia al lunes que quieras como inicio
ON CONFLICT (id) DO NOTHING;

-- 2. TARJETAS
CREATE TABLE IF NOT EXISTS cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  owner TEXT NOT NULL, -- 'Ariel' o 'Paty'
  color TEXT NOT NULL DEFAULT '#6366f1',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO cards (name, owner, color) VALUES
  ('CapitalOne Dorada', 'Ariel', '#f59e0b'),
  ('Sams',              'Ariel', '#3b82f6'),
  ('BestBuy',           'Ariel', '#1d4ed8'),
  ('CapitalOne Dorada', 'Paty',  '#ec4899'),
  ('Amazon',            'Paty',  '#f97316'),
  ('BestBuy',           'Paty',  '#8b5cf6');

-- 3. CATEGORÍAS
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  is_fixed BOOLEAN NOT NULL DEFAULT false
);

INSERT INTO categories (name, emoji, is_fixed) VALUES
  ('Gasto Fijo',     '🔒', true),
  ('Supermercado',   '🛒', false),
  ('Restaurante',    '🍔', false),
  ('Gasolina',       '⛽', false),
  ('Salud',          '💊', false),
  ('Entretenimiento','🎮', false),
  ('Ropa / Retail',  '🛍️', false),
  ('Otros',          '📦', false);

-- 4. GASTOS FIJOS RECURRENTES (catálogo de referencia)
CREATE TABLE IF NOT EXISTS fixed_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('weekly','monthly','annual')),
  card_id UUID REFERENCES cards(id),
  is_active BOOLEAN NOT NULL DEFAULT true
);

-- Se insertan después de crear las tarjetas (necesitas el UUID de BestBuy Ariel)
-- Corre esto DESPUÉS del INSERT de cards:
-- INSERT INTO fixed_expenses (name, amount, frequency, card_id)
-- SELECT 'Aseguranza', 145.00, 'monthly', id FROM cards WHERE name='BestBuy' AND owner='Ariel';
-- SELECT 'Mint Mobile', 500.00, 'annual', id FROM cards WHERE name='BestBuy' AND owner='Ariel';
-- SELECT 'Programas', 57.00, 'monthly', id FROM cards WHERE name='BestBuy' AND owner='Ariel';
-- SELECT 'Google One', 30.00, 'annual', id FROM cards WHERE name='BestBuy' AND owner='Ariel';
-- SELECT 'Toll', 10.00, 'weekly', id FROM cards WHERE name='BestBuy' AND owner='Ariel';

INSERT INTO fixed_expenses (name, amount, frequency, card_id)
SELECT 'Aseguranza', 145.00, 'monthly', id FROM cards WHERE name='BestBuy' AND owner='Ariel'
UNION ALL
SELECT 'Mint Mobile', 500.00, 'annual', id FROM cards WHERE name='BestBuy' AND owner='Ariel'
UNION ALL
SELECT 'Programas', 57.00, 'monthly', id FROM cards WHERE name='BestBuy' AND owner='Ariel'
UNION ALL
SELECT 'Google One', 30.00, 'annual', id FROM cards WHERE name='BestBuy' AND owner='Ariel'
UNION ALL
SELECT 'Toll', 10.00, 'weekly', id FROM cards WHERE name='BestBuy' AND owner='Ariel';

-- 5. GASTOS (tabla principal)
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT now(),
  amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  store TEXT NOT NULL,
  note TEXT,
  card_id UUID NOT NULL REFERENCES cards(id),
  category_id UUID NOT NULL REFERENCES categories(id),
  is_fixed BOOLEAN NOT NULL DEFAULT false,
  recorded_by TEXT NOT NULL DEFAULT 'Ariel' -- quién lo registró
);

-- 6. REALTIME — habilitar para la tabla de gastos
ALTER TABLE expenses REPLICA IDENTITY FULL;

-- 7. ROW LEVEL SECURITY — permitir acceso público (app familiar sin auth)
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE fixed_expenses ENABLE ROW LEVEL SECURITY;

-- Políticas: acceso completo con anon key (sin login)
CREATE POLICY "public_all_expenses" ON expenses FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all_cards" ON cards FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all_categories" ON categories FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all_settings" ON settings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all_fixed" ON fixed_expenses FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- VISTA ÚTIL: gasto por semana (para el rolling budget)
-- ============================================
CREATE OR REPLACE VIEW weekly_summary AS
SELECT
  date_trunc('week', created_at AT TIME ZONE 'America/Chicago')::date AS week_start,
  SUM(amount) AS total_spent,
  COUNT(*) AS transaction_count
FROM expenses
GROUP BY 1
ORDER BY 1 DESC;
