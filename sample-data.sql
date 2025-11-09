SET FOREIGN_KEY_CHECKS = 0;

INSERT INTO Category (id, name) VALUES
(2, 'Dinners'),
(3, 'Sides');

INSERT INTO Product (id, number, name, category_id) VALUES
(100, 'P-100', 'Steak Dinner', 2),
(101, 'P-101', 'Mac & Cheese', 3);

INSERT INTO AtomicIngredient (name) VALUES
('Salt'),
('Pepper'),
('Sodium Phosphate'),
('Beef Steak'),
('Pasta');

INSERT INTO CompositeIngredient (name, atomic_parent) VALUES
('Seasoning Blend', 'Salt'),
('Super Seasoning', 'Salt');

INSERT INTO Manufacturer (name) VALUES
('MFG001'), -- John Smith
('MFG002'); -- Alice Lee

-- No address in Sample Data
INSERT INTO Supplier (id, name, address) VALUES
(20, 'Supplier A', NULL),
(21, 'Supplier B', NULL);

-- Missing supplier ID, effective end date, 
INSERT INTO Formulation (id, pack_size, unit_price, validity_date, version_number) VALUES
(1, 8, 20.0, '2025-01-01', '1');


-- Might be formulation materials, but should be ingredientID instead of material Name
INSERT INTO IngredientComposition (compound_ingredient_name, material_name, quantity_ounces) VALUES
('Seasoning Blend', 'Salt', 6.0),
('Seasoning Blend', 'Pepper', 2.0);

-- Missing USER


-- Not sure if this is needed
INSERT INTO Batch (id, size, lot_number) VALUES
-- Ingredient Batches
(10001, 1000, '101-20-B0001_raw'), -- Actual lot_number will be computed by trigger
(10002, 800, '101-21-B0001_raw'),
(10003, 500, '101-20-B0002_raw'),
(10004, 500, '101-20-B0003_raw'),
(10005, 1200, '102-20-B0001_raw'),
(10006, 3000, '106-20-B0005_raw'),
(10007, 600, '106-20-B0006_raw'),
(10008, 1000, '108-20-B0001_raw'),
(10009, 6300, '108-20-B0003_raw'),
(10010, 100, '201-20-B0001_raw'),
(10011, 20, '201-20-B0002_raw'),
-- Product Batches
(20001, 100, '100-MFG001-B0901'),
(20002, 300, '101-MFG002-B0101');

-- Has null because we separated the two types of ingredient
INSERT INTO IngredientBatch (
    atomic_ingredient_name,
    composite_ingredient_name,
    supplier_id,
    generic_batch_id,
    on_hand_quantity_oz,
    per_unit_cost,
    expiration_date,
    formulation_id -- Only applicable for composite ingredients with a specific formulation
) VALUES
('Salt', NULL, 20, 10001, 1000.0, 0.1, '2025-11-15', NULL),
('Salt', NULL, 21, 10002, 800.0, 0.08, '2025-10-30', NULL),
('Salt', NULL, 20, 10003, 500.0, 0.1, '2025-11-01', NULL),
('Salt', NULL, 20, 10004, 500.0, 0.1, '2025-12-15', NULL),
('Pepper', NULL, 20, 10005, 1200.0, 0.3, '2025-12-15', NULL),
('Beef Steak', NULL, 20, 10006, 3000.0, 0.5, '2025-12-15', NULL),
('Beef Steak', NULL, 20, 10007, 600.0, 0.5, '2025-12-20', NULL),
('Pasta', NULL, 20, 10008, 1000.0, 0.25, '2025-09-28', NULL),
('Pasta', NULL, 20, 10009, 6300.0, 0.25, '2025-12-31', NULL),
(NULL, 'Seasoning Blend', 20, 10010, 100.0, 2.5, '2025-11-30', 1), -- Links to Formulation ID 1
(NULL, 'Seasoning Blend', 20, 10011, 20.0, 2.5, '2025-12-30', 1);

-- Not in Sample Data
INSERT INTO RecipePlan (plan_id, product_id, version_number, creation_date, standard_batch_size) VALUES
(1, 100, 1, CURDATE(), 500), -- For 'Steak Dinner'
(2, 101, 1, CURDATE(), 300); -- For 'Mac & Cheese'


-- ProductBOM?
INSERT INTO RecipeIngredient (plan_id, ingredient_name, required_quantity_oz) VALUES
(1, 'Beef Steak', 6.0),     -- For Steak Dinner (Product 100), ingredient_id 106
(1, 'Seasoning Blend', 0.2), -- For Steak Dinner (Product 100), ingredient_id 201
(2, 'Pasta', 7.0),          -- For Mac & Cheese (Product 101), ingredient_id 108
(2, 'Salt', 0.5),           -- For Mac & Cheese (Product 101), ingredient_id 101
(2, 'Pepper', 2.0);         -- For Mac & Cheese (Product 101), ingredient_id 102


INSERT INTO ProductBatch (
    lot_number,
    product_id,
    manufacturer_name,
    generic_batch_id,
    produced_quantity,
    production_date,
    expiration_date,
    batch_total_cost,
    unit_cost,
    recipe_plan_id
) VALUES
('100-MFG001-B0901', 100, 'MFG001', 20001, 100, '2025-09-26', '2025-11-15', 0.0, 0.0, 1), -- For Steak Dinner
('101-MFG002-B0101', 101, 'MFG002', 20002, 300, '2025-09-10', '2025-10-30', 0.0, 0.0, 2); -- For Mac & Cheese

-- Called ProductConsumption in sample data
INSERT INTO IngredientConsumption (product_lot_number, ingredient_lot_number, consumed_quantity_oz) VALUES
('100-MFG001-B0901', 'Beef Steak-20-10007', 600.0), -- Maps to sample 106-20-B0006
('100-MFG001-B0901', 'Seasoning Blend-20-10011', 20.0), -- Maps to sample 201-20-B0002
('101-MFG002-B0101', 'Salt-20-10003', 150.0), -- Maps to sample 101-20-B0002
('101-MFG002-B0101', 'Pasta-20-10009', 2100.0), -- Maps to sample 108-20-B0003
('101-MFG002-B0101', 'Pepper-20-10005', 600.0); -- Maps to sample 102-20-B0001

-- Maybe rename into ConflictPairs
INSERT INTO IngredientIncompatibility (ingredient_name_1, ingredient_name_2) VALUES
('Seasoning Blend', 'Sodium Phosphate'), -- From 201 and 104
('Beef Steak', 'Sodium Phosphate');     -- From 106 and 104


SET FOREIGN_KEY_CHECKS = 1;