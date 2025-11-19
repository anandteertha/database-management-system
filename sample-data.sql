-- fixed-sample-data.sql
SET FOREIGN_KEY_CHECKS = 0;

-- 1) Users (UserDetails)
INSERT INTO UserDetails (id, first_name, last_name, role_code)
VALUES
  ('MFG001', 'John', 'Smith', 'MANUFACTURER'),
  ('MFG002', 'Alice', 'Lee', 'MANUFACTURER'),
  ('SUP020', 'Jane', 'Doe', 'SUPPLIER'),
  ('SUP021', 'James', 'Miller', 'SUPPLIER'),
  ('VIEW001', 'Bob', 'Johnson', 'VIEWER')
ON DUPLICATE KEY UPDATE
  first_name = VALUES(first_name),
  last_name  = VALUES(last_name),
  role_code  = VALUES(role_code);

-- 2) Categories
INSERT INTO Category (id, name)
VALUES
  (2, 'Dinners'),
  (3, 'Sides')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- 3) Products
INSERT INTO Product (id, name, number, category_id, standard_batch_units)
VALUES
  (100, 'Steak Dinner', 'P-100', 2, 100),
  (101, 'Mac & Cheese', 'P-101', 3, 300)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  number = VALUES(number),
  category_id = VALUES(category_id),
  standard_batch_units = VALUES(standard_batch_units);

-- 4) Ingredients
INSERT INTO Ingredient (id, name, type)
VALUES
  (101, 'Salt', 'ATOMIC'),
  (102, 'Pepper', 'ATOMIC'),
  (104, 'Sodium Phosphate', 'ATOMIC'),
  (106, 'Beef Steak', 'ATOMIC'),
  (108, 'Pasta', 'ATOMIC'),
  (201, 'Seasoning Blend', 'COMPOUND'),
  (301, 'Super Seasoning', 'COMPOUND')
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  type = VALUES(type);

-- 5) IngredientFormulation
-- Updated dates to ensure validity covers the current date (Nov 2025)
INSERT INTO IngredientFormulation
(id, ingredient_id, supplier_id, version_number, validity_start_date, validity_end_date, unit_price, pack_size)
VALUES
  (1, 201, 'SUP020', '1', '2025-01-01', '2030-12-30', 20.0, 8)
ON DUPLICATE KEY UPDATE
  supplier_id = VALUES(supplier_id),
  version_number = VALUES(version_number),
  validity_start_date = VALUES(validity_start_date),
  validity_end_date = VALUES(validity_end_date),
  unit_price = VALUES(unit_price),
  pack_size = VALUES(pack_size);

-- 6) FormulationMaterial
INSERT INTO FormulationMaterial (formulation_id, ingredient_id, quantity)
VALUES
  (1, 101, 6.0),
  (1, 102, 2.0)
ON DUPLICATE KEY UPDATE quantity = VALUES(quantity);

-- 7) ProductBOM
INSERT INTO ProductBOM (product_id, ingredient_id, quantity)
VALUES
  (100, 106, 6.0),
  (100, 201, 0.2),
  (101, 108, 7.0),
  (101, 101, 0.5),
  (101, 102, 2.0)
ON DUPLICATE KEY UPDATE quantity = VALUES(quantity);

-- 8) IngredientBatch
-- UPDATED: Expiration dates set to late 2026 to satisfy the "90 days from now" trigger rule.
-- Current date is assumed to be Nov 2025, so expiration > Feb 2026 is required.
INSERT INTO IngredientBatch (lot_number, ingredient_id, supplier_id, batch_id, quantity, per_unit_cost, expiration_date)
VALUES
  ('TEMP1', 101, 'SUP020', 1, 1000, 0.10, '2026-06-15'),
  ('TEMP2', 101, 'SUP021', 1, 800, 0.08, '2026-06-30'),
  ('TEMP3', 101, 'SUP020', 2, 500, 0.10, '2026-07-01'),
  ('TEMP4', 101, 'SUP020', 3, 500, 0.10, '2026-08-15'),
  ('TEMP5', 102, 'SUP020', 1, 1200, 0.30, '2026-08-15'),
  ('TEMP6', 106, 'SUP020', 5, 3000, 0.50, '2026-09-15'),
  ('TEMP7', 106, 'SUP020', 6, 600, 0.50, '2026-09-20'),
  ('TEMP8', 108, 'SUP020', 1, 1000, 0.25, '2026-06-28'),
  ('TEMP9', 108, 'SUP020', 3, 6300, 0.25, '2026-12-31'),
  ('TEMP10', 201, 'SUP020', 1, 100, 2.50, '2026-10-30'),
  ('TEMP11', 201, 'SUP020', 2, 20, 2.50, '2026-11-30')
ON DUPLICATE KEY UPDATE
  quantity = VALUES(quantity),
  expiration_date = VALUES(expiration_date);

-- 9) ProductBatch
-- Production dates kept in late 2025. Expiration dates pushed to 2026.
INSERT INTO ProductBatch
(lot_number, product_id, manufacturer_id, batch_id, produced_quantity, production_date, expiration_date, batch_total_cost, unit_cost)
VALUES
  ('100-MFG001-B0901', 100, 'MFG001', 901, 100, '2025-09-26', '2026-09-26', 0, 0),
  ('101-MFG002-B0101', 101, 'MFG002', 101, 300, '2025-09-10', '2026-09-10', 0, 0)
ON DUPLICATE KEY UPDATE
  produced_quantity = VALUES(produced_quantity),
  production_date = VALUES(production_date),
  expiration_date = VALUES(expiration_date);

-- 10) IngredientConsumption
-- Using the triggered lot names (ID-SUPPLIER-BATCHID)
INSERT INTO IngredientConsumption (product_lot_number, ingredient_lot_number, consumed_quantity_oz)
VALUES
  -- For Steak Dinner (Batch 6 of Beef, Batch 2 of Seasoning)
  ('100-MFG001-B0901', '106-SUP020-6', 600.0),
  ('100-MFG001-B0901', '201-SUP020-2', 20.0),
  
  -- For Mac & Cheese
  ('101-MFG002-B0101', '101-SUP020-2', 150.0),
  ('101-MFG002-B0101', '108-SUP020-3', 2100.0),
  ('101-MFG002-B0101', '102-SUP020-1', 600.0)
ON DUPLICATE KEY UPDATE consumed_quantity_oz = VALUES(consumed_quantity_oz);

-- 11) Recalculate Costs
CALL RecalculateBatchCost('100-MFG001-B0901');
CALL RecalculateBatchCost('101-MFG002-B0101');

-- 12) IngredientIncompatibility
INSERT INTO IngredientIncompatibility (ingredient_a, ingredient_b)
VALUES
  (106, 104)
ON DUPLICATE KEY UPDATE ingredient_a = ingredient_a;

SET FOREIGN_KEY_CHECKS = 1;