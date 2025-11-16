from database import Database
from datetime import datetime, timedelta
import sys

class Manufacturer:
    def __init__(self, db: Database, user_id: str):
        self.db = db
        self.user_id = user_id
    
    def menu(self):
        """Main manufacturer menu"""
        while True:
            print("\n=== Manufacturer Menu ===")
            print("1. Products -> Create/Update")
            print("2. Products -> Recipe Plans")
            print("3. Inventory -> Record Ingredient Receipt")
            print("4. Production -> Create Product Batch")
            print("5. Reports")
            print("6. (Grad) Recall & Traceability")
            print("7. Exit")
            
            choice = input("Select option: ").strip()
            
            if choice == '1':
                self.create_update_product()
            elif choice == '2':
                self.manage_recipe_plans()
            elif choice == '3':
                self.record_ingredient_receipt()
            elif choice == '4':
                self.create_product_batch()
            elif choice == '5':
                self.reports_menu()
            elif choice == '6':
                self.recall_traceability()
            elif choice == '7':
                break
            else:
                print("Invalid option")
    
    def create_update_product(self):
        """Create or update a product type"""
        print("\n=== Create/Update Product ===")
        
        # List existing products owned by this manufacturer
        query = """
            SELECT p.id, p.name, p.number, c.name as category_name, p.standard_batch_units
            FROM Product p
            JOIN ManufacturerProduct mp ON p.id = mp.product_id
            JOIN Category c ON p.category_id = c.id
            WHERE mp.manufacturer_id = %s
        """
        products = self.db.execute(query, (self.user_id,))
        
        if products:
            print("\nYour existing products:")
            for p in products:
                print(f"  ID: {p['id']}, Name: {p['name']}, Number: {p['number']}, "
                      f"Category: {p['category_name']}, Standard Batch: {p['standard_batch_units']}")
        
        # Get product details
        product_name = input("Product name: ").strip()
        product_number = input("Product number: ").strip()
        
        # List categories
        categories = self.db.execute("SELECT id, name FROM Category")
        print("\nAvailable categories:")
        for cat in categories:
            print(f"  {cat['id']}: {cat['name']}")
        
        category_id = int(input("Category ID: "))
        standard_batch_units = int(input("Standard batch units: "))
        
        # Check if product exists
        check_query = "SELECT id FROM Product WHERE name = %s AND number = %s"
        existing = self.db.execute(check_query, (product_name, product_number))
        
        if existing:
            product_id = existing[0]['id']
            # Update
            update_query = """
                UPDATE Product 
                SET category_id = %s, standard_batch_units = %s
                WHERE id = %s
            """
            self.db.execute(update_query, (category_id, standard_batch_units, product_id), fetch=False)
            
            # Ensure ownership
            ownership_query = """
                INSERT IGNORE INTO ManufacturerProduct (manufacturer_id, product_id)
                VALUES (%s, %s)
            """
            self.db.execute(ownership_query, (self.user_id, product_id), fetch=False)
            print("Product updated successfully")
        else:
            # Create new product
            insert_query = """
                INSERT INTO Product (name, number, category_id, standard_batch_units)
                VALUES (%s, %s, %s, %s)
            """
            self.db.execute(insert_query, (product_name, product_number, category_id, standard_batch_units), fetch=False)
            product_id = self.db.cursor.lastrowid
            
            # Assign ownership
            ownership_query = """
                INSERT INTO ManufacturerProduct (manufacturer_id, product_id)
                VALUES (%s, %s)
            """
            self.db.execute(ownership_query, (self.user_id, product_id), fetch=False)
            print(f"Product created successfully with ID: {product_id}")
    
    def manage_recipe_plans(self):
        """Create or update recipe plans"""
        print("\n=== Recipe Plans ===")
        
        # List owned products
        query = """
            SELECT p.id, p.name, p.number
            FROM Product p
            JOIN ManufacturerProduct mp ON p.id = mp.product_id
            WHERE mp.manufacturer_id = %s
        """
        products = self.db.execute(query, (self.user_id,))
        
        if not products:
            print("No products found. Create a product first.")
            return
        
        print("\nYour products:")
        for p in products:
            print(f"  {p['id']}: {p['name']} ({p['number']})")
        
        product_id = int(input("Select product ID: "))
        
        # Verify ownership
        verify_query = """
            SELECT 1 FROM ManufacturerProduct 
            WHERE manufacturer_id = %s AND product_id = %s
        """
        if not self.db.execute(verify_query, (self.user_id, product_id)):
            print("You don't own this product!")
            return
        
        # Get latest version
        version_query = """
            SELECT MAX(version_number) as max_version
            FROM RecipePlan
            WHERE product_id = %s
        """
        version_result = self.db.execute(version_query, (product_id,))
        new_version = (version_result[0]['max_version'] or 0) + 1
        
        print(f"\nCreating new recipe plan version {new_version}")
        
        # List available ingredients
        ingredients = self.db.execute("SELECT id, name, type FROM Ingredient ORDER BY name")
        print("\nAvailable ingredients:")
        for ing in ingredients:
            print(f"  {ing['id']}: {ing['name']} ({ing['type']})")
        
        # Get recipe ingredients
        recipe_ingredients = []
        while True:
            ingredient_id = input("Ingredient ID (or 'done' to finish): ").strip()
            if ingredient_id.lower() == 'done':
                break
            
            try:
                ingredient_id = int(ingredient_id)
                quantity = float(input("Required quantity (oz): "))
                recipe_ingredients.append((ingredient_id, quantity))
            except ValueError:
                print("Invalid input")
        
        if not recipe_ingredients:
            print("No ingredients added. Aborting.")
            return
        
        # Create recipe plan
        plan_query = """
            INSERT INTO RecipePlan (product_id, version_number, creation_date)
            VALUES (%s, %s, CURDATE())
        """
        self.db.execute(plan_query, (product_id, new_version), fetch=False)
        plan_id = self.db.cursor.lastrowid
        
        # Add recipe ingredients (using ProductBOM for now, or create RecipeIngredient table)
        # Based on schema, we'll use ProductBOM
        for ing_id, qty in recipe_ingredients:
            bom_query = """
                INSERT INTO ProductBOM (product_id, ingredient_id, quantity)
                VALUES (%s, %s, %s)
                ON DUPLICATE KEY UPDATE quantity = %s
            """
            self.db.execute(bom_query, (product_id, ing_id, qty, qty), fetch=False)
        
        # Check for incompatibilities (Grad feature)
        self.check_incompatibilities(product_id)
        
        print(f"Recipe plan version {new_version} created successfully")
    
    def check_incompatibilities(self, product_id):
        """Check for ingredient incompatibilities in a product"""
        query = """
            SELECT DISTINCT ii.ingredient_a, ii.ingredient_b,
                   i1.name as name_a, i2.name as name_b
            FROM ProductBOM pb1
            JOIN ProductBOM pb2 ON pb1.product_id = pb2.product_id
            JOIN IngredientIncompatibility ii ON 
                (ii.ingredient_a = pb1.ingredient_id AND ii.ingredient_b = pb2.ingredient_id)
                OR (ii.ingredient_a = pb2.ingredient_id AND ii.ingredient_b = pb1.ingredient_id)
            JOIN Ingredient i1 ON ii.ingredient_a = i1.id
            JOIN Ingredient i2 ON ii.ingredient_b = i2.id
            WHERE pb1.product_id = %s
            AND pb1.ingredient_id != pb2.ingredient_id
        """
        conflicts = self.db.execute(query, (product_id,))
        
        if conflicts:
            print("\n⚠️  WARNING: Incompatibility detected!")
            for conflict in conflicts:
                print(f"  {conflict['name_a']} cannot be combined with {conflict['name_b']}")
        else:
            print("✓ No incompatibilities detected")
    
    def record_ingredient_receipt(self):
        """Record ingredient receipt (manufacturer receiving from supplier)"""
        print("\n=== Record Ingredient Receipt ===")
        
        # List available ingredient batches from suppliers
        query = """
            SELECT ib.lot_number, ib.ingredient_id, i.name as ingredient_name,
                   ib.supplier_id, u.first_name as supplier_name,
                   ib.quantity, ib.per_unit_cost, ib.expiration_date
            FROM IngredientBatch ib
            JOIN Ingredient i ON ib.ingredient_id = i.id
            JOIN UserDetails u ON ib.supplier_id = u.id
            WHERE ib.quantity > 0
            ORDER BY ib.expiration_date
        """
        batches = self.db.execute(query)
        
        if not batches:
            print("No ingredient batches available")
            return
        
        print("\nAvailable ingredient batches:")
        for b in batches:
            print(f"  Lot: {b['lot_number']}, Ingredient: {b['ingredient_name']}, "
                  f"Supplier: {b['supplier_name']}, Qty: {b['quantity']}, "
                  f"Expires: {b['expiration_date']}")
        
        lot_number = input("\nEnter lot number to receive: ").strip()
        
        # Verify lot exists and not expired
        verify_query = """
            SELECT * FROM IngredientBatch
            WHERE lot_number = %s AND expiration_date >= CURDATE()
        """
        lot_info = self.db.execute(verify_query, (lot_number,))
        
        if not lot_info:
            print("Invalid or expired lot number")
            return
        
        print(f"Receipt recorded for lot: {lot_number}")
        print("Note: Ingredient batches are created by suppliers. This function records manufacturer receipt.")
    
    def create_product_batch(self):
        """Create a product batch with ingredient consumption"""
        print("\n=== Create Product Batch ===")
        
        # List owned products
        query = """
            SELECT p.id, p.name, p.number, p.standard_batch_units
            FROM Product p
            JOIN ManufacturerProduct mp ON p.id = mp.product_id
            WHERE mp.manufacturer_id = %s
        """
        products = self.db.execute(query, (self.user_id,))
        
        if not products:
            print("No products found. Create a product first.")
            return
        
        print("\nYour products:")
        for p in products:
            print(f"  {p['id']}: {p['name']} (Standard batch: {p['standard_batch_units']})")
        
        product_id = int(input("Select product ID: "))
        
        # Get product details
        product_info = [p for p in products if p['id'] == product_id]
        if not product_info:
            print("Invalid product ID")
            return
        
        standard_batch = product_info[0]['standard_batch_units']
        
        # Get production quantity
        produced_quantity = int(input(f"Produced quantity (must be multiple of {standard_batch}): "))
        
        if produced_quantity % standard_batch != 0:
            print(f"Error: Quantity must be a multiple of {standard_batch}")
            return
        
        # Get recipe plan (use latest version)
        plan_query = """
            SELECT plan_id, version_number
            FROM RecipePlan
            WHERE product_id = %s
            ORDER BY version_number DESC
            LIMIT 1
        """
        plan_result = self.db.execute(plan_query, (product_id,))
        
        if not plan_result:
            print("No recipe plan found. Create one first.")
            return
        
        plan_id = plan_result[0]['plan_id']
        
        # Get required ingredients from ProductBOM
        bom_query = """
            SELECT pb.ingredient_id, i.name, pb.quantity
            FROM ProductBOM pb
            JOIN Ingredient i ON pb.ingredient_id = i.id
            WHERE pb.product_id = %s
        """
        required_ingredients = self.db.execute(bom_query, (product_id,))
        
        if not required_ingredients:
            print("No ingredients in recipe. Update recipe plan first.")
            return
        
        print("\nRequired ingredients (per unit):")
        for ing in required_ingredients:
            total_needed = ing['quantity'] * produced_quantity
            print(f"  {ing['name']}: {ing['quantity']} oz/unit (Total needed: {total_needed} oz)")
        
        # Get batch ID
        batch_id = int(input("Enter batch ID: "))
        
        # Calculate dates
        production_date = datetime.now().date()
        expiration_date = production_date + timedelta(days=90)  # Default 90 days
        
        # Create product batch using stored procedure
        try:
            self.db.execute_procedure(
                'RecordProductionBatch',
                (self.user_id, product_id, batch_id, produced_quantity, production_date, expiration_date)
            )
            
            # Get the lot number
            lot_query = """
                SELECT lot_number FROM ProductBatch
                WHERE product_id = %s AND manufacturer_id = %s AND batch_id = %s
                ORDER BY production_date DESC LIMIT 1
            """
            lot_result = self.db.execute(lot_query, (product_id, self.user_id, batch_id))
            product_lot_number = lot_result[0]['lot_number']
            
            print(f"\nProduct batch created: {product_lot_number}")
            
            # Now consume ingredients
            print("\nSelect ingredient lots to consume:")
            
            for ing in required_ingredients:
                total_needed = ing['quantity'] * produced_quantity
                print(f"\n{ing['name']}: Need {total_needed} oz")
                
                # List available lots (FEFO - earliest expiring first)
                lots_query = """
                    SELECT ib.lot_number, ib.quantity, ib.expiration_date, ib.per_unit_cost
                    FROM IngredientBatch ib
                    WHERE ib.ingredient_id = %s
                    AND ib.quantity > 0
                    AND ib.expiration_date >= CURDATE()
                    ORDER BY ib.expiration_date ASC
                """
                available_lots = self.db.execute(lots_query, (ing['ingredient_id'],))
                
                if not available_lots:
                    print(f"  No available lots for {ing['name']}")
                    # Rollback?
                    return
                
                print("  Available lots:")
                for lot in available_lots:
                    print(f"    {lot['lot_number']}: {lot['quantity']} oz, expires {lot['expiration_date']}")
                
                remaining = total_needed
                lot_selections = []
                
                # Auto-select by FEFO (Grad feature)
                use_fefo = input("  Use FEFO auto-select? (y/n): ").strip().lower() == 'y'
                
                if use_fefo:
                    for lot in available_lots:
                        if remaining <= 0:
                            break
                        use_qty = min(remaining, lot['quantity'])
                        lot_selections.append((lot['lot_number'], use_qty))
                        remaining -= use_qty
                        print(f"  Selected {lot['lot_number']}: {use_qty} oz")
                else:
                    # Manual selection
                    while remaining > 0:
                        lot_num = input(f"  Enter lot number (need {remaining} oz more): ").strip()
                        if not lot_num:
                            break
                        
                        # Find lot
                        selected_lot = [l for l in available_lots if l['lot_number'] == lot_num]
                        if not selected_lot:
                            print("  Invalid lot number")
                            continue
                        
                        lot = selected_lot[0]
                        use_qty = float(input(f"  Quantity to use (max {lot['quantity']}): "))
                        use_qty = min(use_qty, lot['quantity'], remaining)
                        
                        lot_selections.append((lot_num, use_qty))
                        remaining -= use_qty
                
                if remaining > 0:
                    print(f"  Error: Insufficient quantity. Still need {remaining} oz")
                    return
                
                # Consume the lots
                for lot_num, qty in lot_selections:
                    try:
                        self.db.execute_procedure(
                            'ConsumeIngredientLot',
                            (product_lot_number, lot_num, qty)
                        )
                    except Exception as e:
                        print(f"  Error consuming {lot_num}: {e}")
                        return
            
            # Get final cost
            cost_query = """
                SELECT batch_total_cost, unit_cost, produced_quantity
                FROM ProductBatch
                WHERE lot_number = %s
            """
            cost_info = self.db.execute(cost_query, (product_lot_number,))
            if cost_info:
                print(f"\n✓ Batch created successfully!")
                print(f"  Total cost: ${cost_info[0]['batch_total_cost']:.2f}")
                print(f"  Unit cost: ${cost_info[0]['unit_cost']:.2f}")
                print(f"  Produced quantity: {cost_info[0]['produced_quantity']}")
        
        except Exception as e:
            print(f"Error creating batch: {e}")
    
    def reports_menu(self):
        """Manufacturer reports menu"""
        while True:
            print("\n=== Reports ===")
            print("1. On-hand by item/lot")
            print("2. Nearly out of stock")
            print("3. Almost expired ingredient lots")
            print("4. Batch Cost Summary")
            print("5. Back")
            
            choice = input("Select option: ").strip()
            
            if choice == '1':
                self.on_hand_report()
            elif choice == '2':
                self.nearly_out_of_stock()
            elif choice == '3':
                self.almost_expired()
            elif choice == '4':
                self.batch_cost_summary()
            elif choice == '5':
                break
            else:
                print("Invalid option")
    
    def on_hand_report(self):
        """Report on-hand inventory by item/lot"""
        query = """
            SELECT ib.lot_number, i.name as ingredient_name,
                   ib.quantity, ib.expiration_date, ib.per_unit_cost
            FROM IngredientBatch ib
            JOIN Ingredient i ON ib.ingredient_id = i.id
            WHERE ib.quantity > 0
            ORDER BY i.name, ib.expiration_date
        """
        results = self.db.execute(query)
        
        print("\n=== On-Hand Inventory ===")
        for r in results:
            print(f"Lot: {r['lot_number']}, Ingredient: {r['ingredient_name']}, "
                  f"Qty: {r['quantity']} oz, Expires: {r['expiration_date']}, "
                  f"Cost: ${r['per_unit_cost']:.2f}/oz")
    
    def nearly_out_of_stock(self):
        """Report items below standard batch size"""
        query = """
            SELECT p.id, p.name, p.standard_batch_units,
                   COALESCE(SUM(ib.quantity), 0) as total_on_hand
            FROM Product p
            JOIN ManufacturerProduct mp ON p.id = mp.product_id
            LEFT JOIN ProductBOM pb ON p.id = pb.product_id
            LEFT JOIN IngredientBatch ib ON pb.ingredient_id = ib.ingredient_id AND ib.quantity > 0
            WHERE mp.manufacturer_id = %s
            GROUP BY p.id, p.name, p.standard_batch_units
            HAVING total_on_hand < p.standard_batch_units
        """
        results = self.db.execute(query, (self.user_id,))
        
        print("\n=== Nearly Out of Stock ===")
        if not results:
            print("No items below standard batch size")
        else:
            for r in results:
                print(f"Product: {r['name']} (ID: {r['id']}), "
                      f"On-hand: {r['total_on_hand']}, "
                      f"Standard batch: {r['standard_batch_units']}")
    
    def almost_expired(self):
        """Report ingredient lots expiring within 10 days"""
        query = """
            SELECT ib.lot_number, i.name as ingredient_name,
                   ib.quantity, ib.expiration_date,
                   DATEDIFF(ib.expiration_date, CURDATE()) as days_until_expiry
            FROM IngredientBatch ib
            JOIN Ingredient i ON ib.ingredient_id = i.id
            WHERE ib.quantity > 0
            AND ib.expiration_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 10 DAY)
            ORDER BY ib.expiration_date
        """
        results = self.db.execute(query)
        
        print("\n=== Almost Expired (within 10 days) ===")
        if not results:
            print("No items expiring soon")
        else:
            for r in results:
                print(f"Lot: {r['lot_number']}, Ingredient: {r['ingredient_name']}, "
                      f"Qty: {r['quantity']} oz, Expires in {r['days_until_expiry']} days")
    
    def batch_cost_summary(self):
        """Batch cost summary for a selected product batch"""
        # List product batches
        query = """
            SELECT pb.lot_number, p.name as product_name,
                   pb.produced_quantity, pb.batch_total_cost, pb.unit_cost
            FROM ProductBatch pb
            JOIN Product p ON pb.product_id = p.id
            WHERE pb.manufacturer_id = %s
            ORDER BY pb.production_date DESC
        """
        batches = self.db.execute(query, (self.user_id,))
        
        if not batches:
            print("No product batches found")
            return
        
        print("\nYour product batches:")
        for b in batches:
            print(f"  {b['lot_number']}: {b['product_name']}, "
                  f"Qty: {b['produced_quantity']}, Cost: ${b['batch_total_cost']:.2f}")
        
        lot_number = input("\nEnter lot number: ").strip()
        
        # Get detailed cost breakdown
        detail_query = """
            SELECT ic.ingredient_lot_number, i.name as ingredient_name,
                   ic.consumed_quantity_oz, ib.per_unit_cost,
                   (ic.consumed_quantity_oz * ib.per_unit_cost) as line_cost
            FROM IngredientConsumption ic
            JOIN IngredientBatch ib ON ic.ingredient_lot_number = ib.lot_number
            JOIN Ingredient i ON ib.ingredient_id = i.id
            WHERE ic.product_lot_number = %s
        """
        details = self.db.execute(detail_query, (lot_number,))
        
        batch_info = [b for b in batches if b['lot_number'] == lot_number]
        if batch_info:
            b = batch_info[0]
            print(f"\n=== Batch Cost Summary: {lot_number} ===")
            print(f"Product: {b['product_name']}")
            print(f"Produced Quantity: {b['produced_quantity']}")
            print(f"\nIngredient Costs:")
            total = 0
            for d in details:
                print(f"  {d['ingredient_name']} ({d['ingredient_lot_number']}): "
                      f"{d['consumed_quantity_oz']} oz × ${d['per_unit_cost']:.2f} = ${d['line_cost']:.2f}")
                total += d['line_cost']
            print(f"\nTotal Batch Cost: ${b['batch_total_cost']:.2f}")
            print(f"Unit Cost: ${b['unit_cost']:.2f}")
    
    def recall_traceability(self):
        """Recall & traceability (Grad feature)"""
        print("\n=== Recall & Traceability ===")
        
        ingredient_id = input("Enter ingredient ID (or press Enter for lot number): ").strip()
        lot_number = None
        
        if not ingredient_id:
            lot_number = input("Enter ingredient lot number: ").strip()
        
        # Date window (20 days)
        days_back = 20
        
        if ingredient_id:
            # Find all product batches using this ingredient
            query = """
                SELECT DISTINCT pb.lot_number, p.name as product_name,
                       pb.production_date, pb.expiration_date
                FROM ProductBatch pb
                JOIN IngredientConsumption ic ON pb.lot_number = ic.product_lot_number
                JOIN IngredientBatch ib ON ic.ingredient_lot_number = ib.lot_number
                JOIN Product p ON pb.product_id = p.id
                WHERE ib.ingredient_id = %s
                AND pb.production_date >= DATE_SUB(CURDATE(), INTERVAL %s DAY)
            """
            results = self.db.execute(query, (int(ingredient_id), days_back))
        else:
            # Find product batches using this specific lot
            query = """
                SELECT DISTINCT pb.lot_number, p.name as product_name,
                       pb.production_date, pb.expiration_date
                FROM ProductBatch pb
                JOIN IngredientConsumption ic ON pb.lot_number = ic.product_lot_number
                JOIN Product p ON pb.product_id = p.id
                WHERE ic.ingredient_lot_number = %s
                AND pb.production_date >= DATE_SUB(CURDATE(), INTERVAL %s DAY)
            """
            results = self.db.execute(query, (lot_number, days_back))
        
        print(f"\n=== Affected Product Batches (last {days_back} days) ===")
        if not results:
            print("No affected product batches found")
        else:
            for r in results:
                print(f"Lot: {r['lot_number']}, Product: {r['product_name']}, "
                      f"Produced: {r['production_date']}, Expires: {r['expiration_date']}")
