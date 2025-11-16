-- =========================================================
-- inventory management schema.sql
-- Database schema for manufacturers, suppliers, products,
-- formulations, inventory, batches, consumption and rules.
-- =========================================================
-- Master user table with role information
CREATE TABLE IF NOT EXISTS
    UserDetails (
        id VARCHAR(255) PRIMARY KEY,
        first_name VARCHAR(255) NOT NULL,
        last_name VARCHAR(255),
        address VARCHAR(255),
        role_code ENUM('MANUFACTURER', 'SUPPLIER', 'VIEWER') NOT NULL
    );

-- Product categories (e.g., Snacks, Sauces, Drinks)
CREATE TABLE IF NOT EXISTS
    Category (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255)
    );

-- Products manufactured by manufacturers
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

-- Which manufacturer owns which product (many-to-many)
CREATE TABLE IF NOT EXISTS
    ManufacturerProduct (
        manufacturer_id VARCHAR(255) NOT NULL,
        product_id INT NOT NULL,
        PRIMARY KEY (manufacturer_id, product_id),
        FOREIGN KEY (manufacturer_id) REFERENCES UserDetails (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (product_id) REFERENCES Product (id) ON DELETE CASCADE ON UPDATE CASCADE
    );

-- Recipe versions per product (versioned plans)
CREATE TABLE IF NOT EXISTS
    RecipePlan (
        plan_id INT AUTO_INCREMENT PRIMARY KEY,
        product_id INT NOT NULL,
        version_number INT NOT NULL,
        creation_date DATE NOT NULL,
        UNIQUE (product_id, version_number),
        FOREIGN KEY (product_id) REFERENCES Product (id) ON DELETE CASCADE ON UPDATE CASCADE
    );

-- Ingredients (atomic or compound)
CREATE TABLE IF NOT EXISTS
    Ingredient (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) UNIQUE,
        type ENUM('ATOMIC', 'COMPOUND') NOT NULL
    );

-- Supplier-specific ingredient formulations
-- unit_price is per pack; pack_size is units per pack (e.g., oz per pack)
CREATE TABLE IF NOT EXISTS
    IngredientFormulation (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ingredient_id INT NOT NULL,
        supplier_id VARCHAR(255) NOT NULL,
        version_number VARCHAR(255),
        validity_start_date DATE,
        validity_end_date DATE,
        unit_price DOUBLE,
        -- price per pack
        pack_size INT CHECK (pack_size > 0),
        UNIQUE (ingredient_id, supplier_id, version_number),
        FOREIGN KEY (ingredient_id) REFERENCES Ingredient (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (supplier_id) REFERENCES UserDetails (id) ON DELETE RESTRICT ON UPDATE CASCADE
    );

-- Composition of a formulation (compound ingredients)
CREATE TABLE IF NOT EXISTS
    FormulationMaterial (
        formulation_id INT NOT NULL,
        ingredient_id INT NOT NULL,
        quantity DOUBLE NOT NULL DEFAULT 0 CHECK (quantity >= 0),
        PRIMARY KEY (formulation_id, ingredient_id),
        FOREIGN KEY (formulation_id) REFERENCES IngredientFormulation (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES Ingredient (id) ON DELETE CASCADE ON UPDATE CASCADE
    );

-- Bill of Materials for each product (ingredient + quantity)
CREATE TABLE IF NOT EXISTS
    ProductBOM (
        product_id INT NOT NULL,
        ingredient_id INT NOT NULL,
        quantity DOUBLE NOT NULL DEFAULT 0 CHECK (quantity >= 0),
        PRIMARY KEY (product_id, ingredient_id),
        FOREIGN KEY (product_id) REFERENCES Product (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES Ingredient (id) ON DELETE CASCADE ON UPDATE CASCADE
    );

-- Inventory of ingredient batches in the warehouse
-- quantity + per_unit_cost are in the same unit as consumed_quantity_oz
CREATE TABLE IF NOT EXISTS
    IngredientBatch (
        lot_number VARCHAR(255) PRIMARY KEY,
        ingredient_id INT NOT NULL,
        supplier_id VARCHAR(255) NOT NULL,
        batch_id INT NOT NULL,
        quantity DOUBLE NOT NULL CHECK (quantity >= 0),
        per_unit_cost DOUBLE NOT NULL CHECK (per_unit_cost >= 0),
        expiration_date DATE NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES UserDetails (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_id) REFERENCES Ingredient (id) ON DELETE RESTRICT ON UPDATE CASCADE
    );

-- Production batches of finished products
CREATE TABLE IF NOT EXISTS
    ProductBatch (
        lot_number VARCHAR(255) PRIMARY KEY,
        product_id INT NOT NULL,
        manufacturer_id VARCHAR(255) NOT NULL,
        batch_id INT NOT NULL,
        produced_quantity DOUBLE NOT NULL CHECK (produced_quantity > 0),
        production_date DATE NOT NULL,
        expiration_date DATE NOT NULL,
        batch_total_cost DOUBLE NOT NULL DEFAULT 0 CHECK (batch_total_cost >= 0),
        unit_cost DOUBLE NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
        FOREIGN KEY (product_id) REFERENCES Product (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (manufacturer_id) REFERENCES UserDetails (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (manufacturer_id, product_id) REFERENCES ManufacturerProduct (manufacturer_id, product_id) ON DELETE RESTRICT ON UPDATE CASCADE
    );

-- Consumption of ingredient batches into product batches
CREATE TABLE IF NOT EXISTS
    IngredientConsumption (
        product_lot_number VARCHAR(255) NOT NULL,
        ingredient_lot_number VARCHAR(255) NOT NULL,
        consumed_quantity_oz DOUBLE NOT NULL CHECK (consumed_quantity_oz > 0),
        PRIMARY KEY (product_lot_number, ingredient_lot_number),
        FOREIGN KEY (product_lot_number) REFERENCES ProductBatch (lot_number) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_lot_number) REFERENCES IngredientBatch (lot_number) ON DELETE RESTRICT ON UPDATE CASCADE
    );

-- Pairs of ingredients that must never appear in the same product batch
CREATE TABLE IF NOT EXISTS
    IngredientIncompatibility (
        ingredient_a INT NOT NULL,
        ingredient_b INT NOT NULL,
        PRIMARY KEY (ingredient_a, ingredient_b),
        FOREIGN KEY (ingredient_a) REFERENCES Ingredient (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (ingredient_b) REFERENCES Ingredient (id) ON DELETE RESTRICT ON UPDATE CASCADE
    );