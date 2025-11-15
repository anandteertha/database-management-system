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
        UNIQUE (name, number),
        FOREIGN KEY (category_id) REFERENCES Category (ID) ON DELETE CASCADE ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    Manufacturer (name VARCHAR(255) PRIMARY KEY);

CREATE TABLE IF NOT EXISTS
    AtomicIngredient (
        -- id INT AUTO_INCREMENT PRIMARY KEY (shares with CompositeIngredient so may need to merge)
        name VARCHAR(255) PRIMARY KEY
    );

CREATE TABLE IF NOT EXISTS
    CompositeIngredient (
        -- id INT AUTO_INCREMENT PRIMARY KEY (shares with AtomicIngredient so may need to merge)
        name VARCHAR(255) PRIMARY KEY,
        atomic_parent VARCHAR(255) NOT NULL,
        FOREIGN KEY (atomic_parent) REFERENCES AtomicIngredient (name) ON DELETE RESTRICT ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    Supplier (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255),
        address VARCHAR(255)
    );

CREATE TABLE IF NOT EXISTS
    Formulation (
        id INT AUTO_INCREMENT PRIMARY KEY,
        pack_size INT CHECK (pack_size > 0),
        unit_price DOUBLE,
        validity_date DATE,
        version_number VARCHAR
    );

CREATE TABLE IF NOT EXISTS
    Batch (
        id INT AUTO_INCREMENT PRIMARY KEY,
        size INT CHECK (size > 0),
        lot_number VARCHAR
    );

CREATE TABLE IF NOT EXISTS
    AtomicIngredientSupplier (
        ingredient_name VARCHAR(255),
        supplier_id INT,
        quantity INT,
        formulation_id INT,
        batch_id INT,
        PRIMARY KEY (ingredient_name, supplier_id),
        FOREIGN KEY (ingredient_name) REFERENCES AtomicIngredient (name) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (supplier_id) REFERENCES Supplier (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (formulation_id) REFERENCES Formulation (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (batch_id) REFERENCES Batch (id) ON DELETE RESTRICT ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    CompositeIngredientSupplier (
        ingredient_name VARCHAR(255),
        supplier_id INT,
        quantity INT,
        formulation_id INT,
        batch_id INT,
        PRIMARY KEY (ingredient_name, supplier_id),
        FOREIGN KEY (ingredient_name) REFERENCES CompositeIngredient (name) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (supplier_id) REFERENCES Supplier (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (formulation_id) REFERENCES Formulation (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (batch_id) REFERENCES Batch (id) ON DELETE RESTRICT ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    ManufacturerProduct (
        manufacturer_name VARCHAR(255),
        product_id INT,
        batch_id INT,
        PRIMARY KEY (manufacturer_name, product_id),
        FOREIGN KEY (manufacturer_name) REFERENCES Manufacturer (name) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (product_id) REFERENCES Product (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (batch_id) REFERENCES Batch (id) ON DELETE RESTRICT ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    IngredientComposition (
        compound_ingredient_name VARCHAR(255) NOT NULL,
        material_name VARCHAR(255) NOT NULL,
        quantity_ounces DOUBLE CHECK (quantity_ounces > 0),
        PRIMARY KEY (compound_ingredient_name, material_name),
        FOREIGN KEY (compound_ingredient_name) REFERENCES CompositeIngredient (name) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (material_name) REFERENCES AtomicIngredient (name) ON DELETE RESTRICT ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    RecipePlan (
        plan_id INT AUTO_INCREMENT PRIMARY KEY,
        product_id INT NOT NULL,
        version_number INT NOT NULL,
        creation_date DATE NOT NULL,
        standard_batch_size INT CHECK (standard_batch_size > 0),
        UNIQUE (product_id, version_number),
        FOREIGN KEY (product_id) REFERENCES Product (id) ON DELETE CASCADE ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    RecipeIngredient (
        plan_id INT NOT NULL,
        ingredient_name VARCHAR(255) NOT NULL,
        required_quantity_oz DOUBLE CHECK (required_quantity_oz > 0),
        PRIMARY KEY (plan_id, ingredient_name),
        FOREIGN KEY (plan_id) REFERENCES RecipePlan (plan_id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_name) REFERENCES AtomicIngredient (name) ON DELETE RESTRICT ON UPDATE CASCADE
    );

CREATE TABLE IF NOT EXISTS
    IngredientBatch (
        lot_number VARCHAR PRIMARY KEY,
        ingredient_name VARCHAR(255) NOT NULL,
        supplier_id INT NOT NULL,
        generic_batch_id INT UNIQUE,
        on_hand_quantity_oz DOUBLE NOT NULL CHECK (on_hand_quantity_oz >= 0),
        per_unit_cost DOUBLE NOT NULL CHECK (per_unit_cost >= 0),
        expiration_date DATE NOT NULL,
        formulation_id INT,
        CONSTRAINT chk_ingredient_type CHECK (
            (
                atomic_ingredient_name IS NOT NULL
                AND composite_ingredient_name IS NULL
            )
            OR (
                atomic_ingredient_name IS NULL
                AND composite_ingredient_name IS NOT NULL
            )
        ),
        FOREIGN KEY (atomic_ingredient_name) REFERENCES AtomicIngredient (name) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (composite_ingredient_name) REFERENCES CompositeIngredient (name) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (generic_batch_id) REFERENCES Batch (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (Supplier_id) REFERENCES Supplier (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (formulation_id) REFERENCES Formulation (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    );

CREATE TABLE IF NOT EXISTS
    ProductBatch (
        lot_number VARCHAR PRIMARY KEY,
        product_id INT NOT NULL,
        manufacturer_name VARCHAR(255) NOT NULL,
        generic_batch_id INT UNIQUE,
        produced_quantity INT NOT NULL CHECK (produced_quantity > 0),
        production_date DATE NOT NULL,
        batch_total_cost DOUBLE NOT NULL,
        unit_cost DOUBLE NOT NULL,
        recipe_plan_id INT NOT NULL,
        FOREIGN KEY (generic_batch_id) REFERENCES Batch (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (product_id) REFERENCES Product (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (manufacturer_name) REFERENCES Manufacturer (name) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (recipe_plan_id) REFERENCES RecipePlan (plan_id) ON DELETE RESTRICT ON UPDATE CASCADE
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
        ingredient_name_1 VARCHAR(255) NOT NULL,
        ingredient_name_2 VARCHAR(255) NOT NULL,
        PRIMARY KEY (ingredient_name_1, ingredient_name_2),
        FOREIGN KEY (ingredient_name_1) REFERENCES AtomicIngredient (name) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_name_2) REFERENCES AtomicIngredient (name) ON DELETE RESTRICT ON UPDATE CASCADE
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