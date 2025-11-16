#!/usr/bin/env python3
"""
Database Setup Script
Drops and recreates the database with all schema, triggers, procedures, and sample data
"""

from database_setup import DatabaseSetup

if __name__ == "__main__":
    print("\n" + "="*60)
    print("🗄️  DATABASE SETUP SCRIPT")
    print("="*60)
    print("\nThis script will:")
    print("  • Drop the existing database (if it exists)")
    print("  • Create a fresh database")
    print("  • Load all schema, triggers, and procedures")
    print("  • Insert sample data")
    print("\n⚠️  All existing data will be PERMANENTLY LOST!")
    
    confirm = input("\nAre you sure you want to continue? (type 'YES' to confirm): ").strip()
    
    if confirm != 'YES':
        print("\n❌ Database setup cancelled.")
        exit(0)
    
    setup = DatabaseSetup()
    success = setup.setup_database()
    
    if success:
        exit(0)
    else:
        print("\n❌ Database setup failed. Please check the errors above.")
        exit(1)
