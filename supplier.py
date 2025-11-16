from database import Database
from datetime import datetime, timedelta

class Supplier:
    def __init__(self, db: Database, user_id: str):
        self.db = db
        self.user_id = user_id
    
    def menu(self):
        """Main supplier menu"""
        while True:
            print("\n=== Supplier Menu ===")
            print("1. Manage Ingredients Supplied")
            print("2. Ingredients -> Create/Update")
            print("3. Ingredients -> Do-Not-Combine")
            print("4. Inventory -> Receive Ingredient Batch")
            print("5. Exit")
            
            choice = input("Select option: ").strip()
            
            if choice == '1':
                self.manage_ingredients_supplied()
            elif choice == '2':
                self.create_update_ingredient()
            elif choice == '3':
                self.maintain_do_not_combine()
            elif choice == '4':
                self.receive_ingredient_batch()
            elif choice == '5':
                break
            else:
                print("Invalid option")
    
    def manage_ingredients_supplied(self):
        """Manage which ingredients this supplier can provide"""
        print("\n=== Manage Ingredients Supplied ===")
        
        # List currently supplied ingredients
        query = """
            SELECT DISTINCT i.id, i.name, i.type,
                   COUNT(DISTINCT iform.id) as formulation_count
            FROM Ingredient i
            JOIN IngredientFormulation iform ON i.id = iform.ingredient_id
            WHERE iform.supplier_id = %s
            GROUP BY i.id, i.name, i.type
        """
        supplied = self.db.execute(query, (self.user_id,))
        
        print("\nCurrently supplied ingredients:")
        if supplied:
            for ing in supplied:
                print(f"  {ing['id']}: {ing['name']} ({ing['type']}) - {ing['formulation_count']} formulation(s)")
        else:
            print("  None")
        
        # List all ingredients
        all_ingredients = self.db.execute("SELECT id, name, type FROM Ingredient ORDER BY name")
        print("\nAll available ingredients:")
        for ing in all_ingredients:
            print(f"  {ing['id']}: {ing['name']} ({ing['type']})")
        
        action = input("\nAdd ingredient to supply? (y/n): ").strip().lower()
        if action == 'y':
            try:
                ingredient_id = int(input("Enter ingredient ID: "))
                
                # Verify ingredient exists
                verify_query = "SELECT id, name FROM Ingredient WHERE id = %s"
                ing_check = self.db.execute(verify_query, (ingredient_id,))
                if not ing_check:
                    print("Ingredient not found")
                    return
                
                ingredient_name = ing_check[0]['name']
                
                # Create a basic formulation
                version = input("Version number (default: 1): ").strip() or "1"
                unit_price = float(input("Unit price per pack: $"))
                pack_size = int(input("Pack size (oz): "))
                
                if pack_size <= 0:
                    print("Pack size must be positive")
                    return
                
                validity_start = input("Validity start date (YYYY-MM-DD, or 'today'): ").strip()
                if not validity_start or validity_start.lower() == 'today':
                    validity_start = datetime.now().date()
                else:
                    validity_start = datetime.strptime(validity_start, '%Y-%m-%d').date()
                
                validity_end = input("Validity end date (YYYY-MM-DD, or 'none' for NULL): ").strip()
                validity_end = datetime.strptime(validity_end, '%Y-%m-%d').date() if validity_end and validity_end.lower() != 'none' else None
                
                insert_query = """
                    INSERT INTO IngredientFormulation 
                    (ingredient_id, supplier_id, version_number, unit_price, pack_size, 
                     validity_start_date, validity_end_date)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """
                try:
                    self.db.execute(insert_query, 
                        (ingredient_id, self.user_id, version, unit_price, pack_size, 
                         validity_start, validity_end), fetch=False)
                    print(f"Ingredient '{ingredient_name}' added to supplied list")
                except Exception as e:
                    print(f"Error: {e}")
            except ValueError:
                print("Invalid input")
    
    def create_update_ingredient(self):
        """Create or update an ingredient (atomic or compound)"""
        print("\n=== Create/Update Ingredient ===")
        
        # List existing ingredients
        ingredients = self.db.execute("SELECT id, name, type FROM Ingredient ORDER BY name")
        print("\nExisting ingredients:")
        for ing in ingredients:
            print(f"  {ing['id']}: {ing['name']} ({ing['type']})")
        
        action = input("\nCreate new (n) or update existing (u)? ").strip().lower()
        
        if action == 'n':
            name = input("Ingredient name: ").strip()
            if not name:
                print("Name cannot be empty")
                return
            
            ing_type = input("Type (ATOMIC/COMPOUND): ").strip().upper()
            
            if ing_type not in ['ATOMIC', 'COMPOUND']:
                print("Invalid type. Must be ATOMIC or COMPOUND")
                return
            
            insert_query = "INSERT INTO Ingredient (name, type) VALUES (%s, %s)"
            try:
                self.db.execute(insert_query, (name, ing_type), fetch=False)
                ingredient_id = self.db.cursor.lastrowid
                print(f"Ingredient created with ID: {ingredient_id}")
                
                # If compound, add materials
                if ing_type == 'COMPOUND':
                    self.add_compound_materials(ingredient_id)
            except Exception as e:
                print(f"Error creating ingredient: {e}")
        elif action == 'u':
            try:
                ingredient_id = int(input("Enter ingredient ID to update: "))
                # For now, just confirm it exists
                verify_query = "SELECT id, name, type FROM Ingredient WHERE id = %s"
                ing = self.db.execute(verify_query, (ingredient_id,))
                if ing:
                    print(f"Found: {ing[0]['name']} ({ing[0]['type']})")
                    print("Note: Direct ingredient updates not implemented. Use formulations to manage compound materials.")
                else:
                    print("Ingredient not found")
            except ValueError:
                print("Invalid ingredient ID")
    
    def add_compound_materials(self, compound_id):
        """Add materials to a compound ingredient"""
        print("\nAdd materials (one level only):")
        
        atomic_ingredients = self.db.execute(
            "SELECT id, name FROM Ingredient WHERE type = 'ATOMIC' ORDER BY name"
        )
        print("\nAvailable atomic ingredients:")
        for ing in atomic_ingredients:
            print(f"  {ing['id']}: {ing['name']}")
        
        materials = []
        while True:
            material_id = input("Material ingredient ID (or 'done'): ").strip()
            if material_id.lower() == 'done':
                break
            
            try:
                material_id = int(material_id)
                quantity = float(input("Quantity (oz): "))
                if quantity <= 0:
                    print("Quantity must be positive")
                    continue
                materials.append((material_id, quantity))
            except ValueError:
                print("Invalid input")
        
        if materials:
            print("Note: Materials should be added via formulation.")
            print("Create a formulation for this compound ingredient to define its materials.")
    
    def maintain_do_not_combine(self):
        """Maintain do-not-combine list (Grad feature)"""
        print("\n=== Do-Not-Combine List ===")
        
        # List current incompatibilities
        query = """
            SELECT ii.ingredient_a, ii.ingredient_b,
                   i1.name as name_a, i2.name as name_b
            FROM IngredientIncompatibility ii
            JOIN Ingredient i1 ON ii.ingredient_a = i1.id
            JOIN Ingredient i2 ON ii.ingredient_b = i2.id
            ORDER BY i1.name, i2.name
        """
        incompatibilities = self.db.execute(query)
        
        print("\nCurrent incompatibilities:")
        if incompatibilities:
            for inc in incompatibilities:
                print(f"  {inc['name_a']} <-> {inc['name_b']}")
        else:
            print("  None")
        
        action = input("\nAdd new incompatibility? (y/n): ").strip().lower()
        if action == 'y':
            ingredients = self.db.execute("SELECT id, name FROM Ingredient ORDER BY name")
            print("\nAvailable ingredients:")
            for ing in ingredients:
                print(f"  {ing['id']}: {ing['name']}")
            
            try:
                ing_a = int(input("First ingredient ID: "))
                ing_b = int(input("Second ingredient ID: "))
                
                if ing_a == ing_b:
                    print("Cannot combine ingredient with itself")
                    return
                
                # Ensure consistent ordering (smaller ID first)
                if ing_a > ing_b:
                    ing_a, ing_b = ing_b, ing_a
                
                insert_query = """
                    INSERT INTO IngredientIncompatibility (ingredient_a, ingredient_b)
                    VALUES (%s, %s)
                    ON DUPLICATE KEY UPDATE ingredient_a = ingredient_a
                """
                try:
                    self.db.execute(insert_query, (ing_a, ing_b), fetch=False)
                    print("Incompatibility added successfully")
                except Exception as e:
                    print(f"Error: {e}")
            except ValueError:
                print("Invalid ingredient ID")
    
    def receive_ingredient_batch(self):
        """Receive/create an ingredient batch"""
        print("\n=== Receive Ingredient Batch ===")
        
        # List ingredients this supplier can provide
        query = """
            SELECT DISTINCT i.id, i.name, iform.version_number, iform.pack_size, iform.unit_price
            FROM Ingredient i
            JOIN IngredientFormulation iform ON i.id = iform.ingredient_id
            WHERE iform.supplier_id = %s
            AND (iform.validity_end_date IS NULL OR iform.validity_end_date >= CURDATE())
            AND iform.validity_start_date <= CURDATE()
            ORDER BY i.name, iform.version_number DESC
        """
        supplied = self.db.execute(query, (self.user_id,))
        
        if not supplied:
            print("No ingredients supplied. Add ingredients first via 'Manage Ingredients Supplied'.")
            return
        
        print("\nIngredients you supply (with active formulations):")
        current_ing = None
        for ing in supplied:
            if current_ing != ing['id']:
                current_ing = ing['id']
                print(f"\n  {ing['id']}: {ing['name']}")
            print(f"    Version {ing['version_number']}: Pack size {ing['pack_size']} oz, "
                  f"Price ${ing['unit_price']:.2f}/pack")
        
        try:
            ingredient_id = int(input("\nSelect ingredient ID: "))
            
            # Get formulations for this ingredient
            form_query = """
                SELECT id, version_number, pack_size, unit_price
                FROM IngredientFormulation
                WHERE ingredient_id = %s AND supplier_id = %s
                AND (validity_end_date IS NULL OR validity_end_date >= CURDATE())
                AND validity_start_date <= CURDATE()
                ORDER BY version_number DESC
            """
            formulations = self.db.execute(form_query, (ingredient_id, self.user_id))
            
            if not formulations:
                print("No active formulation found for this ingredient. Create one first.")
                return
            
            form = formulations[0]
            print(f"\nUsing formulation version {form['version_number']}")
            print(f"Pack size: {form['pack_size']} oz")
            print(f"Unit price: ${form['unit_price']:.2f}/pack")
            
            # Get batch details
            batch_id = int(input("Enter batch ID: "))
            packs_received = float(input("Number of packs received: "))
            
            if packs_received <= 0:
                print("Packs received must be positive")
                return
            
            expiration_date_str = input("Expiration date (YYYY-MM-DD): ").strip()
            expiration_date = datetime.strptime(expiration_date_str, '%Y-%m-%d').date()
            
            # Use stored procedure
            try:
                self.db.execute_procedure(
                    'RecordIngredientIntake',
                    (ingredient_id, self.user_id, batch_id, packs_received, 
                     expiration_date, str(form['version_number']))
                )
                
                # Get the created lot number
                lot_query = """
                    SELECT lot_number, quantity, per_unit_cost
                    FROM IngredientBatch
                    WHERE ingredient_id = %s AND supplier_id = %s AND batch_id = %s
                    ORDER BY expiration_date DESC
                    LIMIT 1
                """
                lot_result = self.db.execute(lot_query, (ingredient_id, self.user_id, batch_id))
                
                if lot_result:
                    lot = lot_result[0]
                    print(f"\n✓ Ingredient batch received successfully!")
                    print(f"  Lot Number: {lot['lot_number']}")
                    print(f"  Quantity: {lot['quantity']} oz")
                    print(f"  Per-unit cost: ${lot['per_unit_cost']:.2f}/oz")
                else:
                    print("Batch created but lot number not found")
            except Exception as e:
                print(f"Error: {e}")
        except ValueError:
            print("Invalid input")
        except Exception as e:
            print(f"Error: {e}")



