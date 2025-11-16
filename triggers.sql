-- =========================================================
-- triggers.sql
-- All triggers: lot numbering, role validation, inventory,
-- expiry rules, and incompatibility checks.
-- =========================================================
DELIMITER $$
-- ---------------------------------------------------------
-- 1) IngredientBatch: BEFORE INSERT
--    - Auto-generates lot_number = <ingredient_id>-<supplier_id>-<batch_id>
--    - Enforces: expiration_date must be at least 90 days from today
-- ---------------------------------------------------------
CREATE TRIGGER trg_ingredient_batch_pre_insert BEFORE
INSERT
    ON IngredientBatch FOR EACH ROW BEGIN
    -- Generate a human-readable composite lot number
SET
    NEW.lot_number = CONCAT(
        NEW.ingredient_id,
        '-',
        NEW.supplier_id,
        '-',
        NEW.batch_id
    );

-- Enforce 90-day shelf-life rule at intake
IF NEW.expiration_date < DATE_ADD(CURDATE(), INTERVAL 90 DAY) THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Ingredient intake rejected. Expiration date must be at least 90 days from the intake date.';

END IF;

END $$
-- ---------------------------------------------------------
-- 2) IngredientConsumption: BEFORE INSERT
--    - Validates ingredient lot exists
--    - Rejects expired lots
--    - Ensures sufficient quantity
--    - Enforces IngredientIncompatibility rules per product batch
--    - Decrements IngredientBatch.quantity for the consumed lot
-- ---------------------------------------------------------
CREATE TRIGGER trg_prevent_expired_consumption BEFORE
INSERT
    ON IngredientConsumption FOR EACH ROW BEGIN DECLARE expiration_date_check DATE;

DECLARE current_quantity DOUBLE;

DECLARE v_new_ingredient_id INT;

DECLARE v_conflicts INT;

-- Look up expiration, remaining quantity, and ingredient id
SELECT
    expiration_date,
    quantity,
    ingredient_id INTO expiration_date_check,
    current_quantity,
    v_new_ingredient_id
FROM
    IngredientBatch
WHERE
    lot_number = NEW.ingredient_lot_number;

-- Ingredient lot must exist
IF expiration_date_check IS NULL THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Ingredient lot does not exist.';

END IF;

-- Reject if the lot is already expired
IF CURDATE() > expiration_date_check THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Consumption rejected because the ingredient lot has expired.';

END IF;

-- Reject if there is not enough quantity left
IF current_quantity < NEW.consumed_quantity_oz THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Insufficient quantity in ingredient lot for this consumption.';

END IF;

-- Enforce ingredient incompatibility at product-batch level:
-- New ingredient must not conflict with any other ingredient already used.
SELECT
    COUNT(*) INTO v_conflicts
FROM
    IngredientConsumption ic
    JOIN IngredientBatch ib ON ic.ingredient_lot_number = ib.lot_number
    JOIN IngredientIncompatibility ii ON (
        ii.ingredient_a = v_new_ingredient_id
        AND ii.ingredient_b = ib.ingredient_id
    )
    OR (
        ii.ingredient_b = v_new_ingredient_id
        AND ii.ingredient_a = ib.ingredient_id
    )
WHERE
    ic.product_lot_number = NEW.product_lot_number;

IF v_conflicts > 0 THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Ingredient is incompatible with another ingredient already used in this product batch.';

END IF;

-- Reserve the quantity by decrementing the lot
UPDATE IngredientBatch
SET
    quantity = quantity - NEW.consumed_quantity_oz
WHERE
    lot_number = NEW.ingredient_lot_number;

END $$
-- ---------------------------------------------------------
-- 3) IngredientConsumption: BEFORE UPDATE
--    - Disallow updates to keep consumption as an append-only ledger
--    - If you need to change a record, delete and re-insert
-- ---------------------------------------------------------
CREATE TRIGGER trg_ingredient_consumption_pre_update BEFORE
UPDATE ON IngredientConsumption FOR EACH ROW BEGIN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Updates to IngredientConsumption are not allowed. Delete and re-insert instead.';

END $$
-- ---------------------------------------------------------
-- 4) IngredientConsumption: BEFORE DELETE
--    - Restores IngredientBatch.quantity when a consumption row
--      is removed (inventory roll-back)
-- ---------------------------------------------------------
CREATE TRIGGER trg_ingredient_consumption_pre_delete BEFORE DELETE ON IngredientConsumption FOR EACH ROW BEGIN
UPDATE IngredientBatch
SET
    quantity = quantity + OLD.consumed_quantity_oz
WHERE
    lot_number = OLD.ingredient_lot_number;

END $$
-- ---------------------------------------------------------
-- 5) ManufacturerProduct: BEFORE INSERT
--    - Validates that manufacturer_id exists and has role MANUFACTURER
-- ---------------------------------------------------------
CREATE TRIGGER trg_manufacturer_product_role_check BEFORE
INSERT
    ON ManufacturerProduct FOR EACH ROW BEGIN DECLARE current_role ENUM('MANUFACTURER', 'SUPPLIER', 'VIEWER');

SELECT
    role_code INTO current_role
FROM
    UserDetails
WHERE
    id = NEW.manufacturer_id;

IF current_role IS NULL THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: manufacturer_id does not reference an existing user.';

ELSEIF current_role <> 'MANUFACTURER' THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: manufacturer_id must belong to a MANUFACTURER user.';

END IF;

END $$
-- ---------------------------------------------------------
-- 6) ManufacturerProduct: BEFORE UPDATE
--    - Same validation as insert when manufacturer_id is changed
-- ---------------------------------------------------------
CREATE TRIGGER trg_manufacturer_product_role_check_update BEFORE
UPDATE ON ManufacturerProduct FOR EACH ROW BEGIN DECLARE current_role ENUM('MANUFACTURER', 'SUPPLIER', 'VIEWER');

SELECT
    role_code INTO current_role
FROM
    UserDetails
WHERE
    id = NEW.manufacturer_id;

IF current_role IS NULL THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: manufacturer_id does not reference an existing user.';

ELSEIF current_role <> 'MANUFACTURER' THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: manufacturer_id must belong to a MANUFACTURER user.';

END IF;

END $$
-- ---------------------------------------------------------
-- 7) IngredientFormulation: BEFORE INSERT
--    - Validates that supplier_id belongs to a SUPPLIER user
-- ---------------------------------------------------------
CREATE TRIGGER trg_ingredient_formulation_role_check BEFORE
INSERT
    ON IngredientFormulation FOR EACH ROW BEGIN DECLARE current_role ENUM('MANUFACTURER', 'SUPPLIER', 'VIEWER');

SELECT
    role_code INTO current_role
FROM
    UserDetails
WHERE
    id = NEW.supplier_id;

IF current_role IS NULL THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: supplier_id does not reference an existing user.';

ELSEIF current_role <> 'SUPPLIER' THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: supplier_id must belong to a SUPPLIER user.';

END IF;

END $$
-- ---------------------------------------------------------
-- 8) IngredientFormulation: BEFORE UPDATE
--    - Same validation as insert when supplier_id is changed
-- ---------------------------------------------------------
CREATE TRIGGER trg_ingredient_formulation_role_check_update BEFORE
UPDATE ON IngredientFormulation FOR EACH ROW BEGIN DECLARE current_role ENUM('MANUFACTURER', 'SUPPLIER', 'VIEWER');

SELECT
    role_code INTO current_role
FROM
    UserDetails
WHERE
    id = NEW.supplier_id;

IF current_role IS NULL THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: supplier_id does not reference an existing user (update).';

ELSEIF current_role <> 'SUPPLIER' THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: supplier_id must belong to a SUPPLIER user (update).';

END IF;

END $$
-- ---------------------------------------------------------
-- 9) IngredientBatch: BEFORE INSERT
--    - Validates that supplier_id belongs to a SUPPLIER user
--    (additional to lot-number / 90-day trigger above)
-- ---------------------------------------------------------
CREATE TRIGGER trg_ingredient_batch_role_check BEFORE
INSERT
    ON IngredientBatch FOR EACH ROW BEGIN DECLARE current_role ENUM('MANUFACTURER', 'SUPPLIER', 'VIEWER');

SELECT
    role_code INTO current_role
FROM
    UserDetails
WHERE
    id = NEW.supplier_id;

IF current_role IS NULL THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: supplier_id does not reference an existing user.';

ELSEIF current_role <> 'SUPPLIER' THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: supplier_id must belong to a SUPPLIER user.';

END IF;

END $$
-- ---------------------------------------------------------
-- 10) IngredientBatch: BEFORE UPDATE
--     - Keeps the supplier_id restricted to SUPPLIER when changed
-- ---------------------------------------------------------
CREATE TRIGGER trg_ingredient_batch_role_check_update BEFORE
UPDATE ON IngredientBatch FOR EACH ROW BEGIN DECLARE current_role ENUM('MANUFACTURER', 'SUPPLIER', 'VIEWER');

SELECT
    role_code INTO current_role
FROM
    UserDetails
WHERE
    id = NEW.supplier_id;

IF current_role IS NULL THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: supplier_id does not reference an existing user (update).';

ELSEIF current_role <> 'SUPPLIER' THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: supplier_id must belong to a SUPPLIER user (update).';

END IF;

END $$ DELIMITER;