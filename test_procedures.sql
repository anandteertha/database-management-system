CALL RecordProductionBatch (
    'MFG001', -- manufacturer_id
    100, -- product_id
    1, -- batch_id
    1000, -- produced_quantity
    '2025-11-15',
    '2026-01-15'
);

-- Suppose that created lot_number '100-MFG001-1'
-- and you already have an IngredientBatch with lot_number '5-SUP001-10'
CALL ConsumeIngredientLot ('100-MFG001-1', '5-SUP001-10', 20.0);

CALL RecalculateBatchCost ('<product_lot>');