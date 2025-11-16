-- =========================================================
-- procedures.sql
-- Stored procedures for:
--  - Recording product production batches
--  - Recording ingredient intake from formulations
--  - Consuming ingredients into product batches
--  - Recalculating batch costs
-- =========================================================
DELIMITER $$
-- ---------------------------------------------------------
-- 1) RecalculateBatchCost
--    - Recomputes batch_total_cost and unit_cost for a given
--      product batch based on IngredientConsumption + per_unit_cost
-- ---------------------------------------------------------
CREATE PROCEDURE RecalculateBatchCost (IN p_product_lot_number VARCHAR(255)) BEGIN DECLARE v_produced_quantity DOUBLE;

DECLARE v_total_cost DOUBLE;

-- Fetch produced quantity for this batch
SELECT
    produced_quantity INTO v_produced_quantity
FROM
    ProductBatch
WHERE
    lot_number = p_product_lot_number;

IF v_produced_quantity IS NULL THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Product batch lot does not exist for cost calculation.';

END IF;

-- Compute total ingredient cost for this batch
SELECT
    SUM(ic.consumed_quantity_oz * ib.per_unit_cost) INTO v_total_cost
FROM
    IngredientConsumption ic
    JOIN IngredientBatch ib ON ic.ingredient_lot_number = ib.lot_number
WHERE
    ic.product_lot_number = p_product_lot_number;

-- If no ingredients consumed yet, treat as zero cost
IF v_total_cost IS NULL THEN
SET
    v_total_cost = 0;

END IF;

-- Update the batch with total and per-unit cost
UPDATE ProductBatch
SET
    batch_total_cost = v_total_cost,
    unit_cost = CASE
        WHEN v_produced_quantity > 0 THEN v_total_cost / v_produced_quantity
        ELSE 0
    END
WHERE
    lot_number = p_product_lot_number;

END $$
-- ---------------------------------------------------------
-- 2) RecordProductionBatch
--    - Creates a ProductBatch row
--    - Enforces:
--        * product must exist
--        * produced_quantity > 0
--        * produced_quantity is multiple of standard_batch_units
--        * expiration_date > production_date
--    - lot_number is generated as <product_id>-<manufacturer_id>-<batch_id>
-- ---------------------------------------------------------
CREATE PROCEDURE RecordProductionBatch (
    IN p_manufacturer_id VARCHAR(255),
    IN p_product_id INT,
    IN p_batch_id INT,
    IN p_produced_quantity DOUBLE,
    IN p_production_date DATE,
    IN p_expiration_date DATE
) BEGIN DECLARE v_standard_units INT;

-- Make sure the product exists and get its standard batch size
SELECT
    standard_batch_units INTO v_standard_units
FROM
    Product
WHERE
    id = p_product_id;

IF v_standard_units IS NULL THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Product does not exist.';

END IF;

-- Basic sanity check
IF p_produced_quantity <= 0 THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: produced_quantity must be positive.';

END IF;

-- Enforce: produced_quantity must be a multiple of standard_batch_units
IF MOD(p_produced_quantity, v_standard_units) <> 0 THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: produced_quantity must be a multiple of standard_batch_units.';

END IF;

-- Expiration must be after production
IF p_expiration_date <= p_production_date THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: expiration_date must be after production_date.';

END IF;

-- Insert the product batch
-- The FK (manufacturer_id, product_id) -> ManufacturerProduct
-- ensures that this manufacturer actually owns this product.
INSERT INTO
    ProductBatch (
        lot_number,
        product_id,
        manufacturer_id,
        batch_id,
        produced_quantity,
        production_date,
        expiration_date
    )
VALUES
    (
        CONCAT(
            p_product_id,
            '-',
            p_manufacturer_id,
            '-',
            p_batch_id
        ),
        p_product_id,
        p_manufacturer_id,
        p_batch_id,
        p_produced_quantity,
        p_production_date,
        p_expiration_date
    );

END $$
-- ---------------------------------------------------------
-- 3) RecordIngredientIntake
--    - Records a new IngredientBatch based on an IngredientFormulation
--    - Inputs:
--        * p_ingredient_id      : Ingredient.id
--        * p_supplier_id        : UserDetails.id (role SUPPLIER)
--        * p_batch_id           : Logical batch id (int)
--        * p_packs_received     : Number of packs received
--        * p_expiration_date    : Expiry date of this intake
--        * p_version_number     : IngredientFormulation.version_number
--    - Logic:
--        * Fetches pack_size and unit_price from IngredientFormulation
--        * Computes quantity = pack_size * packs_received
--        * Computes per_unit_cost = unit_price / pack_size
--        * Inserts IngredientBatch (lot_number is set by trigger)
-- ---------------------------------------------------------
CREATE PROCEDURE RecordIngredientIntake (
    IN p_ingredient_id INT,
    IN p_supplier_id VARCHAR(255),
    IN p_batch_id INT,
    IN p_packs_received DOUBLE,
    IN p_expiration_date DATE,
    IN p_version_number VARCHAR(255)
) BEGIN DECLARE v_pack_size INT;

DECLARE v_unit_price DOUBLE;

-- Sanity check on packs received
IF p_packs_received <= 0 THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: packs_received must be positive.';

END IF;

-- Get pack_size and unit_price for the specific formulation
SELECT
    pack_size,
    unit_price INTO v_pack_size,
    v_unit_price
FROM
    IngredientFormulation
WHERE
    ingredient_id = p_ingredient_id
    AND supplier_id = p_supplier_id
    AND version_number = p_version_number;

IF v_pack_size IS NULL THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: No matching ingredient formulation found for given ingredient, supplier, and version.';

END IF;

IF v_pack_size <= 0 THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: formulation pack_size must be positive.';

END IF;

-- Insert the batch; lot_number will be generated by trg_ingredient_batch_pre_insert
INSERT INTO
    IngredientBatch (
        ingredient_id,
        supplier_id,
        batch_id,
        quantity,
        per_unit_cost,
        expiration_date
    )
VALUES
    (
        p_ingredient_id,
        p_supplier_id,
        p_batch_id,
        v_pack_size * p_packs_received,
        v_unit_price / v_pack_size,
        p_expiration_date
    );

END $$
-- ---------------------------------------------------------
-- 4) ConsumeIngredientLot
--    - Records consumption of an ingredient lot into a product batch
--    - Inputs:
--        * p_product_lot_number     : ProductBatch.lot_number
--        * p_ingredient_lot_number  : IngredientBatch.lot_number
--        * p_consumed_quantity_oz   : Quantity consumed from that lot
--    - Logic:
--        * Validates product batch exists
--        * Inserts into IngredientConsumption
--        * BEFORE INSERT trigger checks:
--            - lot existence
--            - not expired
--            - enough quantity
--            - incompatibility rules
--            - decrements IngredientBatch.quantity
--        * Calls RecalculateBatchCost to update batch_total_cost/unit_cost
-- ---------------------------------------------------------
CREATE PROCEDURE ConsumeIngredientLot (
    IN p_product_lot_number VARCHAR(255),
    IN p_ingredient_lot_number VARCHAR(255),
    IN p_consumed_quantity_oz DOUBLE
) BEGIN
-- Basic sanity checks
IF p_consumed_quantity_oz <= 0 THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: consumed_quantity_oz must be positive.';

END IF;

-- Ensure product batch exists (FK would also catch it, but this gives clearer error)
IF NOT EXISTS (
    SELECT
        1
    FROM
        ProductBatch
    WHERE
        lot_number = p_product_lot_number
) THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Product batch lot does not exist.';

END IF;

-- Insert into IngredientConsumption.
-- The BEFORE INSERT trigger trg_prevent_expired_consumption will:
--  - check ingredient lot exists
--  - reject if expired
--  - reject if insufficient quantity
--  - enforce incompatibility rules
--  - decrement IngredientBatch.quantity
INSERT INTO
    IngredientConsumption (
        product_lot_number,
        ingredient_lot_number,
        consumed_quantity_oz
    )
VALUES
    (
        p_product_lot_number,
        p_ingredient_lot_number,
        p_consumed_quantity_oz
    );

-- After successful consumption, recompute the cost for this product batch
CALL RecalculateBatchCost (p_product_lot_number);

END $$ DELIMITER;