import mysql.connector
from mysql.connector import Error
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Database:
    def __init__(self):
        self.connection = None
        self.cursor = None
        self.connect()
    
    def connect(self):
        """Establish database connection"""
        try:
            self.connection = mysql.connector.connect(
                host=os.getenv('DB_HOST', 'localhost'),
                database=os.getenv('DB_NAME', 'inventory_management'),
                user=os.getenv('DB_USER', 'root'),
                password=os.getenv('DB_PASSWORD', ''),
                port=int(os.getenv('DB_PORT', '3306'))
            )
            if self.connection.is_connected():
                self.cursor = self.connection.cursor(dictionary=True)
                print("Connected to database successfully")
        except Error as e:
            print(f"Error connecting to database: {e}")
            raise
    
    def get_connection(self):
        """Get the database connection"""
        if self.connection is None or not self.connection.is_connected():
            self.connect()
        return self.connection
    
    def execute(self, query, params=None, fetch=True):
        """Execute a query and return results"""
        try:
            if params:
                self.cursor.execute(query, params)
            else:
                self.cursor.execute(query)
            
            if fetch:
                return self.cursor.fetchall()
            else:
                self.connection.commit()
                return self.cursor.rowcount
        except Error as e:
            self.connection.rollback()
            print(f"Database error: {e}")
            raise
    
    def execute_procedure(self, procedure_name, params=None):
        """Execute a stored procedure"""
        try:
            if params:
                placeholders = ','.join(['%s'] * len(params))
                query = f"CALL {procedure_name}({placeholders})"
                self.cursor.execute(query, params)
            else:
                self.cursor.execute(f"CALL {procedure_name}()")
            
            self.connection.commit()
            return self.cursor.fetchall()
        except Error as e:
            self.connection.rollback()
            print(f"Procedure error: {e}")
            raise
    
    def close(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.connection and self.connection.is_connected():
            self.connection.close()
            print("Database connection closed")