SET
    FOREIGN_KEY_CHECKS = 0;

INSERT INTO UserDetails (id, first_name, last_name, role_code) VALUES
('20', 'SupplierA', 'Inc.', 'SUPPLIER'),
('21', 'SupplierB', 'Co.', 'SUPPLIER'),
('MFG001', 'Manufacturer', 'One', 'MANUFACTURER'),
('MFG002', 'Manufacturer', 'Two', 'MANUFACTURER');

INSERT INTO
    Category (id, name) VALUES
    (1, 'Dinners'),
    (2, 'Sides');

INSERT INTO Product (id, number, name, category_id, standard_batch_units) VALUES
(100, 'P-100', 'Steak Dinner', 1, 100),
(101, 'P-101', 'Mac & Cheese', 2, 300);

INSERT INTO
    Ingredient (id, name, type)
VALUES
    (1001, 'Salt', 'ATOMIC'),
    (1002, 'Pepper', 'ATOMIC'),
    (1003, 'Sodium Phosphate', 'ATOMIC'),
    (1004, 'Beef Steak', 'ATOMIC'),
    (1005, 'Pasta', 'ATOMIC'),
    (1006, 'Seasoning Blend', 'COMPOUND'),
    (1007, 'Super Seasoning', 'COMPOUND');

INSERT INTO FormulationMaterial (formulation_id, ingredient_id, quantity)
VALUES
(1, 1001, 6), -- Salt (1001): 6 oz
(1, 1002, 2);  -- Pepper (1002): 2 oz

INSERT INTO ProductBOM (product_id, ingredient_id, quantity)
VALUES
(100, 1004, 6),   -- Beef Steak (1004): 6.0 oz
(100, 1006, 0);   -- Seasoning Blend (1006): 0.2 oz (set to 0)

INSERT INTO ProductBOM (product_id, ingredient_id, quantity)
VALUES
(101, 1005, 7),   -- Pasta (1005): 7.0 oz
(101, 1001, 0),   -- Salt (1001): 0.5 oz (set to 0)
(101, 1002, 2);   -- Pepper (1002): 2.0 oz

-- Might be formulation materials, but should be ingredientID instead of material Name
INSERT INTO
    IngredientComposition (
        compound_ingredient_name,
        material_name,
        quantity_ounces
    )
VALUES
    ('Seasoning Blend', 'Salt', 6.0),
    ('Seasoning Blend', 'Pepper', 2.0);

INSERT INTO
    Batch (id, size, lot_number)
VALUES
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


INSERT INTO IngredientBatch (lot_number, ingredient_id, supplier_id, batch_id, quantity, per_unit_cost, expiration_date) VALUES
('Salt-20-10001', 1001, '20', 10001, 1000, 0.1, '2025-11-15'),
('Salt-21-10002', 1001, '21', 10002, 800, 0.08, '2025-10-30'),
('Salt-20-10003', 1001, '20', 10003, 500, 0.1, '2025-11-01'),
('Salt-20-10004', 1001, '20', 10004, 500, 0.1, '2025-12-15'),
('Pepper-20-10005', 1002, '20', 10005, 1200, 0.3, '2025-12-15'),
('BeefSteak-20-10006', 1004, '20', 10006, 3000, 0.5, '2025-12-15'),
('BeefSteak-20-10007', 1004, '20', 10007, 600, 0.5, '2025-12-20'),
('Pasta-20-10008', 1005, '20', 10008, 1000, 0.25, '2025-09-28'),
('Pasta-20-10009', 1005, '20', 10009, 6300, 0.25, '2025-12-31'),
('SeasoningBlend-20-10010', 1006, '20', 10010, 100, 2.5, '2025-11-30'),
('SeasoningBlend-20-10011', 1006, '20', 10011, 20, 2.5, '2025-12-30');


-- Not in Sample Data
INSERT INTO
    RecipePlan (
        plan_id,
        product_id,
        version_number,
        creation_date,
        standard_batch_size
    )
VALUES
    (1, 100, 1, CURDATE(), 500), -- For 'Steak Dinner'
    (2, 101, 1, CURDATE(), 300);

INSERT INTO
    RecipeIngredient (plan_id, ingredient_name, required_quantity_oz)
VALUES
    (1, 'Beef Steak', 6.0), -- For Steak Dinner (Product 100), ingredient_id 106
    (1, 'Seasoning Blend', 0.2), -- For Steak Dinner (Product 100), ingredient_id 201
    (2, 'Pasta', 7.0), -- For Mac & Cheese (Product 101), ingredient_id 108
    (2, 'Salt', 0.5), -- For Mac & Cheese (Product 101), ingredient_id 101
    (2, 'Pepper', 2.0);

-- For Mac & Cheese (Product 101), ingredient_id 102
INSERT INTO ProductBatch (lot_number, product_id, manufacturer_id, batch_id, produced_quantity, production_date, expiration_date) VALUES
(
    '100-MFG001-B0901',
    100,
    'MFG001',
    20001,
    100,
    '2025-09-26',
    '2025-11-15'
),
(
    '101-MFG002-B0101',
    101,
    'MFG002',
    20002,
    300,
    '2025-09-10',
    '2025-10-30'
);

-- For Mac & Cheese
-- Called ProductConsumption in sample data
INSERT INTO
    IngredientConsumption (
        product_lot_number,
        ingredient_lot_number,
        consumed_quantity_oz
    )
VALUES
    ('100-MFG001-B0901', 'Beef Steak-20-10007', 600.0), -- Maps to sample 106-20-B0006
    (
        '100-MFG001-B0901',
        'Seasoning Blend-20-10011',
        20.0
    ), -- Maps to sample 201-20-B0002
    ('101-MFG002-B0101', 'Salt-20-10003', 150.0), -- Maps to sample 101-20-B0002
    ('101-MFG002-B0101', 'Pasta-20-10009', 2100.0), -- Maps to sample 108-20-B0003
    ('101-MFG002-B0101', 'Pepper-20-10005', 600.0);

-- Maps to sample 102-20-B0001
-- Maybe rename into ConflictPairs
INSERT INTO IngredientIncompatibility (ingredient_a, ingredient_b)
VALUES
(1006, 1003), -- Seasoning Blend (1006) and Sodium Phosphate (1003)
(1004, 1003); -- Beef Steak (1004) and Sodium Phosphate (1003)
-- From 106 and 104
SET
    FOREIGN_KEY_CHECKS = 1;