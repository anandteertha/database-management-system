from database import Database

class GeneralViewer:
    def __init__(self, db: Database):
        self.db = db
    
    def menu(self):
        """Main general viewer menu"""
        while True:
            print("\n=== General Viewer Menu ===")
            print("1. Browse Products")
            print("2. Product -> Ingredient List")
            print("3. (Grad) Compare Products")
            print("4. Exit")
            
            choice = input("Select option: ").strip()
            
            if choice == '1':
                self.browse_products()
            elif choice == '2':
                self.generate_ingredient_list()
            elif choice == '3':
                self.compare_products()
            elif choice == '4':
                break
            else:
                print("Invalid option")
    
    def browse_products(self):
        """Browse available product types"""
        query = """
            SELECT p.id, p.name, p.number, c.name as category_name,
                   GROUP_CONCAT(DISTINCT CONCAT(u.first_name, ' ', COALESCE(u.last_name, '')) 
                                ORDER BY u.first_name SEPARATOR ', ') as manufacturers
            FROM Product p
            JOIN Category c ON p.category_id = c.id
            JOIN ManufacturerProduct mp ON p.id = mp.product_id
            JOIN UserDetails u ON mp.manufacturer_id = u.id
            GROUP BY p.id, p.name, p.number, c.name
            ORDER BY c.name, p.name
        """
        products = self.db.execute(query)
        
        print("\n=== Available Products ===")
        if not products:
            print("No products available")
            return
        
        current_category = None
        for p in products:
            if current_category != p['category_name']:
                current_category = p['category_name']
                print(f"\n{current_category}:")
            print(f"  ID: {p['id']}, Name: {p['name']}, Number: {p['number']}")
            print(f"    Manufacturers: {p['manufacturers']}")
    
    def generate_ingredient_list(self):
        """Generate flattened ingredient list for a product"""
        # List all products
        products = self.db.execute("SELECT id, name, number FROM Product ORDER BY name")
        
        if not products:
            print("No products available")
            return
        
        print("\nAvailable products:")
        for p in products:
            print(f"  {p['id']}: {p['name']} ({p['number']})")
        
        try:
            product_id = int(input("\nSelect product ID: "))
        except ValueError:
            print("Invalid product ID")
            return
        
        # Get the latest recipe plan
        plan_query = """
            SELECT plan_id, version_number
            FROM RecipePlan
            WHERE product_id = %s
            ORDER BY version_number DESC
            LIMIT 1
        """
        plan_result = self.db.execute(plan_query, (product_id,))
        
        if not plan_result:
            print("No recipe plan found for this product")
            return
        
        plan_id = plan_result[0]['plan_id']
        version = plan_result[0]['version_number']
        
        # Get product name
        product_query = "SELECT name FROM Product WHERE id = %s"
        product_info = self.db.execute(product_query, (product_id,))
        product_name = product_info[0]['name'] if product_info else f"Product {product_id}"
        
        print(f"\n=== Ingredient List for {product_name} (Plan v{version}) ===")
        
        # Get direct ingredients from ProductBOM
        direct_query = """
            SELECT pb.ingredient_id, i.name, i.type, pb.quantity
            FROM ProductBOM pb
            JOIN Ingredient i ON pb.ingredient_id = i.id
            WHERE pb.product_id = %s
            ORDER BY pb.quantity DESC, i.name
        """
        direct_ingredients = self.db.execute(direct_query, (product_id,))
        
        if not direct_ingredients:
            print("No ingredients found in recipe")
            return
        
        # Flatten compound ingredients one level
        all_ingredients = {}  # ingredient_id -> total quantity
        
        for ing in direct_ingredients:
            if ing['type'] == 'ATOMIC':
                # Direct atomic ingredient
                if ing['ingredient_id'] not in all_ingredients:
                    all_ingredients[ing['ingredient_id']] = {
                        'name': ing['name'],
                        'quantity': 0
                    }
                all_ingredients[ing['ingredient_id']]['quantity'] += ing['quantity']
            else:
                # COMPOUND - flatten one level
                # Get materials from FormulationMaterial
                # First, get the formulation for this compound ingredient
                form_query = """
                    SELECT fm.ingredient_id, i.name, fm.quantity
                    FROM IngredientFormulation inf
                    JOIN FormulationMaterial fm ON inf.id = fm.formulation_id
                    JOIN Ingredient i ON fm.ingredient_id = i.id
                    WHERE inf.ingredient_id = %s
                    ORDER BY fm.quantity DESC
                """
                materials = self.db.execute(form_query, (ing['ingredient_id'],))
                
                if materials:
                    # Calculate total quantity of materials
                    total_material_qty = sum(m['quantity'] for m in materials)
                    
                    # Distribute the compound quantity proportionally
                    for mat in materials:
                        if mat['ingredient_id'] not in all_ingredients:
                            all_ingredients[mat['ingredient_id']] = {
                                'name': mat['name'],
                                'quantity': 0
                            }
                        # Contribution = compound_qty * (material_qty / total_material_qty)
                        contribution = ing['quantity'] * (mat['quantity'] / total_material_qty)
                        all_ingredients[mat['ingredient_id']]['quantity'] += contribution
                else:
                    # No materials found, treat as atomic for display
                    if ing['ingredient_id'] not in all_ingredients:
                        all_ingredients[ing['ingredient_id']] = {
                            'name': ing['name'],
                            'quantity': 0
                        }
                    all_ingredients[ing['ingredient_id']]['quantity'] += ing['quantity']
        
        # Sort by quantity (descending), then by name
        sorted_ingredients = sorted(
            all_ingredients.items(),
            key=lambda x: (-x[1]['quantity'], x[1]['name'])
        )
        
        print("\nFlattened ingredient list (sorted by quantity, largest first):")
        print(f"{'Ingredient':<30} {'Quantity (oz)':>15}")
        print("-" * 50)
        for ing_id, ing_data in sorted_ingredients:
            print(f"{ing_data['name']:<30} {ing_data['quantity']:>15.2f}")
    
    def compare_products(self):
        """Compare two products for incompatibilities (Grad feature)"""
        print("\n=== Compare Products for Incompatibilities ===")
        
        products = self.db.execute("SELECT id, name, number FROM Product ORDER BY name")
        
        if len(products) < 2:
            print("Need at least 2 products to compare")
            return
        
        print("\nAvailable products:")
        for p in products:
            print(f"  {p['id']}: {p['name']} ({p['number']})")
        
        try:
            product1_id = int(input("\nFirst product ID: "))
            product2_id = int(input("Second product ID: "))
        except ValueError:
            print("Invalid product ID")
            return
        
        if product1_id == product2_id:
            print("Cannot compare a product with itself")
            return
        
        # Get product names
        p1_name = next((p['name'] for p in products if p['id'] == product1_id), f"Product {product1_id}")
        p2_name = next((p['name'] for p in products if p['id'] == product2_id), f"Product {product2_id}")
        
        def get_flattened_ingredients(prod_id):
            """Get all ingredient IDs (flattened one level) for a product"""
            # Get direct ingredients
            query = """
                SELECT DISTINCT pb.ingredient_id, i.type
                FROM ProductBOM pb
                JOIN Ingredient i ON pb.ingredient_id = i.id
                WHERE pb.product_id = %s
            """
            ingredients = self.db.execute(query, (prod_id,))
            
            all_ids = set()
            for ing in ingredients:
                all_ids.add(ing['ingredient_id'])
                
                # If compound, add materials
                if ing['type'] == 'COMPOUND':
                    mat_query = """
                        SELECT fm.ingredient_id
                        FROM IngredientFormulation inf
                        JOIN FormulationMaterial fm ON inf.id = fm.formulation_id
                        WHERE inf.ingredient_id = %s
                    """
                    materials = self.db.execute(mat_query, (ing['ingredient_id'],))
                    for mat in materials:
                        all_ids.add(mat['ingredient_id'])
            
            return all_ids
        
        ing1 = get_flattened_ingredients(product1_id)
        ing2 = get_flattened_ingredients(product2_id)
        
        union = ing1.union(ing2)
        
        if len(union) < 2:
            print("Not enough ingredients to compare")
            return
        
        # Check for incompatibilities in the union
        if not union:
            print("No ingredients found in either product")
            return
        
        # Convert to list for SQL IN clause
        ing_list = list(union)
        placeholders = ','.join(['%s'] * len(ing_list))
        
        conflict_query = f"""
            SELECT ii.ingredient_a, ii.ingredient_b,
                   i1.name as name_a, i2.name as name_b
            FROM IngredientIncompatibility ii
            JOIN Ingredient i1 ON ii.ingredient_a = i1.id
            JOIN Ingredient i2 ON ii.ingredient_b = i2.id
            WHERE ii.ingredient_a IN ({placeholders})
            AND ii.ingredient_b IN ({placeholders})
        """
        
        conflicts = self.db.execute(conflict_query, ing_list * 2)
        
        print(f"\n=== Comparison: {p1_name} vs {p2_name} ===")
        print(f"\nProduct 1 ({p1_name}) ingredients: {len(ing1)}")
        print(f"Product 2 ({p2_name}) ingredients: {len(ing2)}")
        print(f"Union of ingredients: {len(union)}")
        
        if conflicts:
            print("\n⚠️  INCOMPATIBILITIES FOUND:")
            for c in conflicts:
                in_prod1_a = c['ingredient_a'] in ing1
                in_prod1_b = c['ingredient_b'] in ing1
                in_prod2_a = c['ingredient_a'] in ing2
                in_prod2_b = c['ingredient_b'] in ing2
                
                location = []
                if (in_prod1_a and in_prod1_b):
                    location.append("Product 1")
                if (in_prod2_a and in_prod2_b):
                    location.append("Product 2")
                if ((in_prod1_a and in_prod2_b) or (in_prod1_b and in_prod2_a)):
                    location.append("Across both products")
                
                loc_str = ", ".join(location) if location else "Unknown"
                print(f"  {c['name_a']} <-> {c['name_b']} (in: {loc_str})")
        else:
            print("\n✓ No incompatibilities found in the union of ingredients")



