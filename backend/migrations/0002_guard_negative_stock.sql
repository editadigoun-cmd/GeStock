-- Prevent stock movements from creating or updating negative inventory.
-- D1 batches are atomic, so a trigger abort rolls back the movement and its stock update.
CREATE TRIGGER IF NOT EXISTS stock_levels_no_negative_insert
BEFORE INSERT ON stock_levels
WHEN NEW.quantity < 0
BEGIN
  SELECT RAISE(ABORT, 'INSUFFICIENT_STOCK');
END;

CREATE TRIGGER IF NOT EXISTS stock_levels_no_negative_update
BEFORE UPDATE ON stock_levels
WHEN NEW.quantity < 0
BEGIN
  SELECT RAISE(ABORT, 'INSUFFICIENT_STOCK');
END;
