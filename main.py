from enums import Role
from database import Database
from manufacturer import Manufacturer
from supplier import Supplier
from general_viewer import GeneralViewer
from queries import Queries
from database_setup import setup_database_menu

def login(db: Database):
    """Login and role selection"""
    print("\n=== Inventory Management System ===")
    print("Select role:")
    print("1. Manufacturer")
    print("2. Supplier")
    print("3. General (Viewer)")
    print("4. View Queries")
    print("5. Database Setup (Drop & Recreate)")
    print("6. Exit")
    
    role_choice = input("Enter choice (1-6): ").strip()
    
    if role_choice == '1':
        user_id = input("Enter manufacturer ID: ").strip()
        # Verify user exists and is manufacturer
        verify_query = "SELECT id FROM UserDetails WHERE id = %s AND role_code = 'MANUFACTURER'"
        user = db.execute(verify_query, (user_id,))
        if not user:
            print("Invalid manufacturer ID")
            return
        manufacturer = Manufacturer(db, user_id)
        manufacturer.menu()
    
    elif role_choice == '2':
        user_id = input("Enter supplier ID: ").strip()
        # Verify user exists and is supplier
        verify_query = "SELECT id FROM UserDetails WHERE id = %s AND role_code = 'SUPPLIER'"
        user = db.execute(verify_query, (user_id,))
        if not user:
            print("Invalid supplier ID")
            return
        supplier = Supplier(db, user_id)
        supplier.menu()
    
    elif role_choice == '3':
        viewer = GeneralViewer(db)
        viewer.menu()
    
    elif role_choice == '4':
        queries = Queries(db)
        queries.menu()
    
    elif role_choice == '5':
        setup_database_menu()
    
    elif role_choice == '6':
        return 'exit'
    
    else:
        print("Invalid choice")
    
    return None

def main():
    """Main entry point"""
    db = None
    try:
        db = Database()
        
        while True:
            result = login(db)
            if result == 'exit':
                break
            
            continue_choice = input("\nContinue? (y/n): ").strip().lower()
            if continue_choice != 'y':
                break
    
    except Exception as e:
        print(f"Error: {e}")
        print("\n💡 Tip: If this is your first time running, try option 5 (Database Setup)")
    finally:
        if db:
            db.close()

if __name__ == "__main__":
    main()