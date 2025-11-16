import mysql.connector
from mysql.connector import Error
import os
from dotenv import load_dotenv
import re
import time

# Load environment variables
load_dotenv()

class DatabaseSetup:
    def __init__(self):
        self.host = os.getenv('DB_HOST', 'localhost')
        self.user = os.getenv('DB_USER', 'root')
        self.password = os.getenv('DB_PASSWORD', '')
        self.port = int(os.getenv('DB_PORT', '3306'))
        self.database_name = os.getenv('DB_NAME', 'inventory_management')
        self.connection = None
    
    def connect_without_db(self):
        """Connect to MySQL server without specifying database"""
        try:
            self.connection = mysql.connector.connect(
                host=self.host,
                user=self.user,
                password=self.password,
                port=self.port
            )
            return True
        except Error as e:
            print(f"❌ Error connecting to MySQL server: {e}")
            return False
    
    def connect_with_db(self):
        """Connect to MySQL server with database"""
        try:
            self.connection = mysql.connector.connect(
                host=self.host,
                user=self.user,
                password=self.password,
                port=self.port,
                database=self.database_name
            )
            return True
        except Error as e:
            print(f"❌ Error connecting to database: {e}")
            return False
    
    def execute_sql_file(self, filepath, description):
        """Execute SQL file, handling DELIMITER properly"""
        if not os.path.exists(filepath):
            print(f"   ❌ Error: File not found: {filepath}")
            return False
        
        print(f"   📄 Reading {description}...")
        
        try:
            with open(filepath, 'r', encoding='utf-8') as file:
                sql_content = file.read()
            
            cursor = self.connection.cursor()
            
            # Check if file uses DELIMITER (for procedures/triggers)
            if 'DELIMITER' in sql_content.upper():
                # Handle DELIMITER blocks
                # Remove DELIMITER commands and split by $$
                content = sql_content
                
                # Remove DELIMITER $$ and DELIMITER ; lines
                content = re.sub(r'DELIMITER\s+\$\$', '', content, flags=re.IGNORECASE)
                content = re.sub(r'DELIMITER\s*;', '', content, flags=re.IGNORECASE)
                
                # Split by $$ (the delimiter used in procedures/triggers)
                blocks = [block.strip() for block in content.split('$$') if block.strip()]
                
                executed = 0
                for block in blocks:
                    # Remove comments
                    block = re.sub(r'--.*$', '', block, flags=re.MULTILINE)
                    block = block.strip()
                    
                    if block and not block.startswith('--'):
                        try:
                            # Execute the block
                            cursor.execute(block)
                            executed += 1
                        except Error as e:
                            error_msg = str(e)
                            # Ignore "already exists" errors
                            if 'already exists' not in error_msg.lower():
                                print(f"      ⚠️  Warning: {error_msg[:100]}")
                cursor.close()
                self.connection.commit()
                print(f"   ✅ {description} executed successfully ({executed} statements)")
            else:
                # Regular SQL file without DELIMITER
                # Split by semicolon
                statements = []
                current_statement = ""
                
                for line in sql_content.split('\n'):
                    # Skip comment-only lines
                    stripped = line.strip()
                    if stripped.startswith('--') or not stripped:
                        continue
                    
                    current_statement += line + '\n'
                    
                    # Check if line ends with semicolon
                    if ';' in line:
                        # Find the last semicolon that's not in a string
                        parts = current_statement.split(';')
                        if len(parts) > 1:
                            statement = ';'.join(parts[:-1]) + ';'
                            statements.append(statement.strip())
                            current_statement = parts[-1]
                
                # Add remaining statement if any
                if current_statement.strip():
                    statements.append(current_statement.strip())
                
                executed = 0
                for statement in statements:
                    if statement and not statement.startswith('--'):
                        try:
                            cursor.execute(statement)
                            executed += 1
                        except Error as e:
                            error_msg = str(e)
                            if 'already exists' not in error_msg.lower() and 'duplicate' not in error_msg.lower():
                                print(f"      ⚠️  Warning: {error_msg[:100]}")
                
                cursor.close()
                self.connection.commit()
                print(f"   ✅ {description} executed successfully ({executed} statements)")
            
            return True
            
        except Exception as e:
            print(f"   ❌ Error executing {description}: {e}")
            import traceback
            print(f"   Traceback: {traceback.format_exc()}")
            return False
    
    def setup_database(self):
        """Main setup function"""
        print("\n" + "="*60)
        print("🗄️  DATABASE SETUP & INITIALIZATION")
        print("="*60)
        
        # Step 1: Connect to MySQL server
        print("\n[1/6] Connecting to MySQL server...")
        if not self.connect_without_db():
            return False
        print("   ✅ Connected to MySQL server")
        time.sleep(0.3)
        
        # Step 2: Drop database
        print("\n[2/6] Dropping existing database (if any)...")
        try:
            cursor = self.connection.cursor()
            cursor.execute(f"DROP DATABASE IF EXISTS `{self.database_name}`")
            print(f"   ✅ Database '{self.database_name}' dropped (if it existed)")
            cursor.close()
            time.sleep(0.3)
        except Error as e:
            print(f"   ⚠️  Warning: {e}")
        
        # Step 3: Create database
        print("\n[3/6] Creating new database...")
        try:
            cursor = self.connection.cursor()
            cursor.execute(f"CREATE DATABASE `{self.database_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
            print(f"   ✅ Database '{self.database_name}' created successfully")
            cursor.close()
            time.sleep(0.3)
        except Error as e:
            print(f"   ❌ Error creating database: {e}")
            if self.connection:
                self.connection.close()
            return False
        
        # Step 4: Reconnect with database
        self.connection.close()
        print("\n[4/6] Connecting to new database...")
        if not self.connect_with_db():
            return False
        print(f"   ✅ Connected to database '{self.database_name}'")
        time.sleep(0.3)
        
        # Step 5: Execute SQL files
        print("\n[5/6] Executing SQL files...")
        print("-" * 60)
        
        sql_files = [
            ('inventory-management.sql', 'Database Schema'),
            ('triggers.sql', 'Database Triggers'),
            ('stored_procedures.sql', 'Stored Procedures'),
            ('sample-data.sql', 'Sample Data')
        ]
        
        success_count = 0
        for filename, description in sql_files:
            if self.execute_sql_file(filename, description):
                success_count += 1
            time.sleep(0.2)
        
        print("-" * 60)
        if success_count == len(sql_files):
            print(f"   ✅ All {success_count} SQL files executed successfully")
        else:
            print(f"   ⚠️  {success_count}/{len(sql_files)} SQL files executed")
        
        # Step 6: Verify
        print("\n[6/6] Verifying database setup...")
        try:
            cursor = self.connection.cursor()
            
            # Count tables
            cursor.execute(f"""
                SELECT COUNT(*) as count 
                FROM information_schema.tables 
                WHERE table_schema = '{self.database_name}'
            """)
            table_count = cursor.fetchone()[0]
            
            # Count procedures
            cursor.execute(f"""
                SELECT COUNT(*) as count 
                FROM information_schema.routines 
                WHERE routine_schema = '{self.database_name}' 
                AND routine_type = 'PROCEDURE'
            """)
            proc_count = cursor.fetchone()[0]
            
            # Count triggers
            cursor.execute(f"""
                SELECT COUNT(*) as count 
                FROM information_schema.triggers 
                WHERE trigger_schema = '{self.database_name}'
            """)
            trigger_count = cursor.fetchone()[0]
            
            # List tables
            cursor.execute("SHOW TABLES")
            tables = [row[0] for row in cursor.fetchall()]
            
            cursor.close()
            
            print(f"   📊 Database Statistics:")
            print(f"      • Tables: {table_count}")
            print(f"      • Stored Procedures: {proc_count}")
            print(f"      • Triggers: {trigger_count}")
            
            if tables:
                print(f"\n   📋 Created Tables:")
                for table in tables:
                    print(f"      • {table}")
            
            if table_count > 0:
                print(f"\n   ✅ Database setup verified successfully!")
            else:
                print(f"\n   ⚠️  Warning: No tables found!")
            
        except Error as e:
            print(f"   ⚠️  Verification error: {e}")
        
        # Close connection
        if self.connection and self.connection.is_connected():
            self.connection.close()
        
        print("\n" + "="*60)
        print("🎉 DATABASE SETUP COMPLETE!")
        print("="*60)
        print(f"\n✅ Database '{self.database_name}' is ready to use!")
        print("   You can now run the application with: python main.py\n")
        
        return True

def setup_database_menu():
    """Menu function for database setup"""
    print("\n" + "="*60)
    print("⚠️  WARNING: This will DELETE all existing data!")
    print("="*60)
    print("\nThis operation will:")
    print("  • Drop the existing database (if it exists)")
    print("  • Create a fresh database")
    print("  • Load all schema, triggers, and procedures")
    print("  • Insert sample data")
    print("\n⚠️  All existing data will be PERMANENTLY LOST!")
    
    confirm = input("\nAre you sure you want to continue? (type 'YES' to confirm): ").strip()
    
    if confirm != 'YES':
        print("\n❌ Database setup cancelled.")
        return
    
    setup = DatabaseSetup()
    setup.setup_database()
