from database import Database

class Queries:
    def __init__(self, db: Database):
        self.db = db
    
    def menu(self):
        """Queries menu"""
        while True:
            print("\n=== Required Queries ===")
            print("1. List ingredients and lot number of last batch of Steak Dinner (100) by MFG001")
            print("2. For MFG002, list suppliers and total spent")
            print("3. Find unit cost for product lot 100-MFG001-B0901")
            print("4. Find conflicting ingredients for lot 100-MFG001-B0901")
            print("5. Which manufacturers has supplier James Miller (21) NOT supplied to?")
            print("6. Back")
            
            choice = input("Select query: ").strip()
            
            if choice == '1':
                self.query1()
            elif choice == '2':
                self.query2()
            elif choice == '3':
                self.query3()
            elif choice == '4':
                self.query4()
            elif choice == '5':
                self.query5()
            elif choice == '6':
                break
            else:
                print("Invalid option")
    
    def query1(self):
        """List ingredients and lot number of last batch of product type Steak Dinner (100) made by manufacturer MFG001"""
        print("\n=== Query 1: Last batch of Steak Dinner (100) by MFG001 ===")
        
        # Get the latest batch first
        batch_query = """
            SELECT lot_number, production_date
            FROM ProductBatch
            WHERE product_id = 100 AND manufacturer_id = 'MFG001'
            ORDER BY production_date DESC, batch_id DESC
            LIMIT 1
        """
        batch_result = self.db.execute(batch_query)
        
        if not batch_result:
            print("No batches found for Steak Dinner (100) by MFG001")
            return
        
        lot_number = batch_result[0]['lot_number']
        production_date = batch_result[0]['production_date']
        
        print(f"Product Lot Number: {lot_number}")
        print(f"Production Date: {production_date}")
        
        # Get ingredients and their lot numbers
        query = """
            SELECT i.name as ingredient_name, 
                   ic.ingredient_lot_number,
                   ic.consumed_quantity_oz
            FROM IngredientConsumption ic
            JOIN IngredientBatch ib ON ic.ingredient_lot_number = ib.lot_number
            JOIN Ingredient i ON ib.ingredient_id = i.id
            WHERE ic.product_lot_number = %s
            ORDER BY i.name
        """
        ingredients = self.db.execute(query, (lot_number,))
        
        print("\nIngredients used:")
        for ing in ingredients:
            print(f"  {ing['ingredient_name']}: Lot {ing['ingredient_lot_number']} "
                  f"({ing['consumed_quantity_oz']} oz)")
    
    def query2(self):
        """For manufacturer MFG002, list all suppliers and total amount spent"""
        print("\n=== Query 2: Suppliers and Total Spent by MFG002 ===")
        
        query = """
            SELECT u.id as supplier_id, 
                   CONCAT(u.first_name, ' ', COALESCE(u.last_name, '')) as supplier_name,
                   SUM(ic.consumed_quantity_oz * ib.per_unit_cost) as total_spent
            FROM ProductBatch pb
            JOIN IngredientConsumption ic ON pb.lot_number = ic.product_lot_number
            JOIN IngredientBatch ib ON ic.ingredient_lot_number = ib.lot_number
            JOIN UserDetails u ON ib.supplier_id = u.id
            WHERE pb.manufacturer_id = 'MFG002'
            GROUP BY u.id, u.first_name, u.last_name
            ORDER BY total_spent DESC
        """
        
        results = self.db.execute(query)
        
        if not results:
            print("No suppliers found or no purchases made by MFG002")
        else:
            print(f"\nTotal suppliers: {len(results)}")
            print("\nSupplier Details:")
            total_all = 0
            for r in results:
                total_spent = float(r['total_spent']) if r['total_spent'] else 0
                total_all += total_spent
                print(f"  Supplier ID: {r['supplier_id']}")
                print(f"  Name: {r['supplier_name']}")
                print(f"  Total Spent: ${total_spent:.2f}")
                print()
            print(f"Grand Total: ${total_all:.2f}")
    
    def query3(self):
        """Find unit cost for product lot 100-MFG001-B0901"""
        print("\n=== Query 3: Unit Cost for 100-MFG001-B0901 ===")
        
        query = """
            SELECT pb.lot_number, 
                   p.name as product_name,
                   pb.unit_cost, 
                   pb.batch_total_cost, 
                   pb.produced_quantity,
                   pb.production_date,
                   pb.expiration_date
            FROM ProductBatch pb
            JOIN Product p ON pb.product_id = p.id
            WHERE pb.lot_number = '100-MFG001-B0901'
        """
        
        results = self.db.execute(query)
        
        if not results:
            print("Lot number 100-MFG001-B0901 not found")
        else:
            r = results[0]
            print(f"Lot Number: {r['lot_number']}")
            print(f"Product: {r['product_name']}")
            print(f"Unit Cost: ${r['unit_cost']:.2f}")
            print(f"Batch Total Cost: ${r['batch_total_cost']:.2f}")
            print(f"Produced Quantity: {r['produced_quantity']}")
            print(f"Production Date: {r['production_date']}")
            print(f"Expiration Date: {r['expiration_date']}")
    
    def query4(self):
        """Based on ingredients in product lot 100-MFG001-B0901, find conflicting ingredients"""
        print("\n=== Query 4: Conflicting Ingredients for 100-MFG001-B0901 ===")
        
        # First, get all ingredients currently in the product batch
        current_ingredients_query = """
            SELECT DISTINCT ib.ingredient_id, i.name as ingredient_name
            FROM IngredientConsumption ic
            JOIN IngredientBatch ib ON ic.ingredient_lot_number = ib.lot_number
            JOIN Ingredient i ON ib.ingredient_id = i.id
            WHERE ic.product_lot_number = '100-MFG001-B0901'
        """
        current_ingredients = self.db.execute(current_ingredients_query)
        
        if not current_ingredients:
            print("No ingredients found for this product lot")
            return
        
        print("Current ingredients in the batch:")
        current_ids = []
        for ing in current_ingredients:
            current_ids.append(ing['ingredient_id'])
            print(f"  {ing['ingredient_id']}: {ing['ingredient_name']}")
        
        if not current_ids:
            print("No ingredients to check conflicts for")
            return
        
        # Find all ingredients that conflict with any current ingredient
        # but are NOT already in the batch
        placeholders = ','.join(['%s'] * len(current_ids))
        
        conflict_query = f"""
            SELECT DISTINCT 
                CASE 
                    WHEN ii.ingredient_a IN ({placeholders}) THEN ii.ingredient_b
                    ELSE ii.ingredient_a
                END as conflicting_ingredient_id,
                i.name as conflicting_ingredient_name
            FROM IngredientIncompatibility ii
            JOIN Ingredient i ON (
                (ii.ingredient_a IN ({placeholders}) AND i.id = ii.ingredient_b)
                OR (ii.ingredient_b IN ({placeholders}) AND i.id = ii.ingredient_a)
            )
            WHERE (ii.ingredient_a IN ({placeholders}) OR ii.ingredient_b IN ({placeholders}))
            AND CASE 
                WHEN ii.ingredient_a IN ({placeholders}) THEN ii.ingredient_b
                ELSE ii.ingredient_a
            END NOT IN ({placeholders})
        """
        
        # Execute with parameters
        params = current_ids * 7  # Used 7 times in the query
        conflicts = self.db.execute(conflict_query, params)
        
        print("\nIngredients that CANNOT be included (conflicts):")
        if not conflicts:
            print("  No conflicting ingredients found")
        else:
            for c in conflicts:
                print(f"  {c['conflicting_ingredient_id']}: {c['conflicting_ingredient_name']}")
    
    def query5(self):
        """Which manufacturers has supplier James Miller (21) NOT supplied to?"""
        print("\n=== Query 5: Manufacturers NOT supplied by James Miller (21) ===")
        
        query = """
            SELECT DISTINCT u.id as manufacturer_id, 
                   CONCAT(u.first_name, ' ', COALESCE(u.last_name, '')) as manufacturer_name
            FROM UserDetails u
            WHERE u.role_code = 'MANUFACTURER'
            AND u.id NOT IN (
                SELECT DISTINCT pb.manufacturer_id
                FROM ProductBatch pb
                JOIN IngredientConsumption ic ON pb.lot_number = ic.product_lot_number
                JOIN IngredientBatch ib ON ic.ingredient_lot_number = ib.lot_number
                WHERE ib.supplier_id = '21'
            )
            ORDER BY u.id
        """
        
        results = self.db.execute(query)
        
        if not results:
            print("All manufacturers have been supplied by supplier 21 (James Miller)")
        else:
            print(f"Manufacturers NOT supplied by supplier 21:")
            for r in results:
                print(f"  {r['manufacturer_id']}: {r['manufacturer_name']}")



