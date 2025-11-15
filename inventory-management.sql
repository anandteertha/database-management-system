CREATE TABLE IF NOT EXISTS
    UserDetails (
        id VARCHAR(255) PRIMARY KEY,
        first_name VARCHAR(255) NOT NULL,
        last_name VARCHAR(255),
        address VARCHAR(255),
        role_code VARCHAR(15) ENUM('MANUFACTURER', 'SUPPLIER', 'VIEWER') NOT NULL
    );

CREATE TABLE IF NOT EXISTS
    Category (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255)
    );

CREATE TABLE IF NOT EXISTS
    Product (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255),
        number VARCHAR(255),
        category_id INT,
        standard_batch_units INT,
        UNIQUE (name, number),
        FOREIGN KEY (category_id) REFERENCES Category (id) ON DELETE CASCADE ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    Ingredient (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) UNIQUE,
        type VARCHAR(10) ENUM('ATOMIC', 'COMPOUND') NOT NULL
    );

CREATE TABLE IF NOT EXISTS
    IngredientFormulation (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ingredient_id INT NOT NULL,
        supplier_id INT NOT NULL,
        version_number VARCHAR(255),
        validity_start_date DATE,
        validity_end_date DATE,
        unit_price DOUBLE, -- this is price per pack
        pack_size INT CHECK (pack_size > 0),
        UNIQUE (ingredient_id, supplier_id),
        FOREIGN KEY (ingredient_id) REFERENCES Ingredient (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (supplier_id) REFERENCES UserDetails (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    );

CREATE TABLE IF NOT EXISTS
    FormulationMaterial (
        formulation_id INT NOT NULL,
        ingredient_id INT NOT NULL,
        quantity INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
        PRIMARY KEY (formulation_id, ingredient_id),
        FOREIGN KEY (formulation_id) REFERENCES IngredientFormulation (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES Ingredient (id) ON DELETE CASCADE ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    ProductBOM (
        product_id INT NOT NULL,
        ingredient_id INT NOT NULL,
        quantity INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
        PRIMARY KEY (product_id, ingredient_id),
        FOREIGN KEY (product_id) REFERENCES Product (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES Ingredient (id) ON DELETE CASCADE ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    IngredientBatch (
        lot_number VARCHAR(255) PRIMARY KEY,
        ingredient_id INT NOT NULL -- should be checked with a trigger if it matches or not!,
        supplier_id INT NOT NULL -- should be checked with a trigger if it matches or not!,
        batch_id INT NOT NULL, -- should be filled with a trigger!
        quantity INT NOT NULL CHECK (quantity >= 0),
        per_unit_cost DOUBLE NOT NULL CHECK (per_unit_cost >= 0),
        expiration_date DATE NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES UserDetails (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES Ingredient (id) ON DELETE RESTRICT ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    ProductBatch (
        lot_number VARCHAR(255) PRIMARY KEY,
        product_id INT NOT NULL -- should be checked with a trigger if it matches or not!,
        manufacturer_id INT NOT NULL, -- should be filled with a trigger!
        batch_id INT NOT NULL, -- should be filled with a trigger!
        produced_quantity INT NOT NULL CHECK (produced_quantity > 0),
        production_date DATE NOT NULL,
        expiration_date DATE NOT NULL,
        FOREIGN KEY (product_id) REFERENCES Product (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (manufacturer_id) REFERENCES UserDetails (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    );

CREATE TABLE IF NOT EXISTS
    IngredientConsumption (
        product_lot_number VARCHAR(255) NOT NULL,
        ingredient_lot_number VARCHAR(255) NOT NULL,
        consumed_quantity_oz DOUBLE NOT NULL CHECK (consumed_quantity_oz > 0),
        PRIMARY KEY (product_lot_number, ingredient_lot_number),
        FOREIGN KEY (product_lot_number) REFERENCES ProductBatch (lot_number) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_lot_number) REFERENCES IngredientBatch (lot_number) ON DELETE RESTRICT ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    IngredientIncompatibility (
        ingredient_a VARCHAR(255) NOT NULL,
        ingredient_b VARCHAR(255) NOT NULL,
        PRIMARY KEY (ingredient_a, ingredient_b),
        FOREIGN KEY (ingredient_a) REFERENCES Ingredient (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_b) REFERENCES Ingredient (id) ON DELETE RESTRICT ON UPDATE CASCADE
    );

-- changes the end of the procudure delimiter to $$ instead of ;
DELIMITER $$
-- 1. TRIGGER: Compute Ingredient Lot Number & Enforce 90-Day Intake Rule
-- This trigger runs BEFORE an ingredient batch is inserted.
CREATE TRIGGER trg_ingredient_batch_pre_insert BEFORE
INSERT
    ON IngredientBatch FOR EACH ROW BEGIN DECLARE v_ingredient_name VARCHAR(255);

-- Determine the ingredient name from the exclusive arc columns
IF NEW.atomic_ingredient_name IS NOT NULL THEN
SET
    v_ingredient_name = NEW.atomic_ingredient_name;

ELSEIF NEW.composite_ingredient_name IS NOT NULL THEN
SET
    v_ingredient_name = NEW.composite_ingredient_name;

END IF;

-- Compute Lot Number: <ingredientId>-<supplierId>-<batchId> [cite: 166]
SET
    NEW.lot_number = CONCAT(
        v_ingredient_name,
        '-',
        NEW.supplier_id,
        '-',
        NEW.generic_batch_id
    );

-- Enforce 90-day expiration check [cite: 71, 105]
IF NEW.expiration_date < DATE_ADD(CURDATE(), INTERVAL 90 DAY) THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Ingredient intake rejected. Expiration date must be at least 90 days from the intake date.';

END IF;

END $$
-- 2. TRIGGER: Prevent Expired Consumption
-- This trigger runs BEFORE an ingredient is consumed by a product batch.
CREATE TRIGGER trg_prevent_expired_consumption BEFORE
INSERT
    ON IngredientConsumption FOR EACH ROW BEGIN DECLARE expiration_date_check DATE;

-- Look up the expiration date from the IngredientBatch table
SELECT
    expiration_date INTO expiration_date_check
FROM
    IngredientBatch
WHERE
    lot_number = NEW.ingredient_lot_number;

-- Reject if the current date is past the expiration date [cite: 168]
IF expiration_date_check IS NOT NULL
AND CURDATE() > expiration_date_check THEN SIGNAL SQLSTATE '45000'
SET
    MESSAGE_TEXT = 'Error: Consumption rejected because the ingredient lot has expired.';

END IF;

END $$ DELIMITER;