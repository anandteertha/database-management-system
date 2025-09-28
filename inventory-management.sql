CREATE TABLE IF NOT EXISTS Category (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS Product (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    number VARCHAR(255),
    category_id INT,
    UNIQUE (name, number)
    FOREIGN KEY (category_id)
        REFERENCES Category(ID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS Manufacturer (
    name VARCHAR(255) PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS AtomicIngredient (
    name VARCHAR(255) PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS CompositeIngredient (
    name VARCHAR(255) PRIMARY KEY,
    atomic_parent VARCHAR(255) NOT NULL,
    FOREIGN KEY (atomic_parent)
        REFERENCES AtomicIngredient(name)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS Supplier (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    address VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS Formulation (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pack_size INT CHECK (pack_size > 0),
    unit_price DOUBLE,
    validity_date DATE,
    version_number VARCHAR
);

CREATE TABLE IF NOT EXISTS Batch (
    id INT AUTO_INCREMENT PRIMARY KEY,
    size INT CHECK (size > 0),
    lot_number VARCHAR
);

CREATE TABLE IF NOT EXISTS AtomicIngredientSupplier (
    ingredient_name VARCHAR(255),
    supplier_id INT,
    quantity INT,
    formulation_id INT,
    batch_id INT,
    PRIMARY KEY (ingredient_name, supplier_id),
    FOREIGN KEY (ingredient_name) 
        REFERENCES AtomicIngredient(name)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    FOREIGN KEY (supplier_id)
        REFERENCES Supplier(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    FOREIGN KEY (formulation_id)
        REFERENCES Formulation(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    FOREIGN KEY (batch_id)
        REFERENCES Batch(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS CompositeIngredientSupplier (
    ingredient_name VARCHAR(255),
    supplier_id INT,
    quantity INT,
    formulation_id INT,
    batch_id INT,
    PRIMARY KEY (ingredient_name, supplier_id),
    FOREIGN KEY (ingredient_name) 
        REFERENCES CompositeIngredient(name)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    FOREIGN KEY (supplier_id)
        REFERENCES Supplier(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    FOREIGN KEY (formulation_id)
        REFERENCES Formulation(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    FOREIGN KEY (batch_id)
        REFERENCES Batch(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS ManufacturerProduct (
    manufacturer_name VARCHAR(255),
    product_id INT,
    batch_id INT,
    PRIMARY KEY (manufacturer_name, product_id),
    FOREIGN KEY (manufacturer_name)
        REFERENCES Manufacturer(name)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    FOREIGN KEY (product_id)
        REFERENCES Product(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
    FOREIGN KEY (batch_id)
        REFERENCES Batch(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);