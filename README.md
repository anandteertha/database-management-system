# 🏭 Inventory Management System

<div align="center">

![Python](https://img.shields.io/badge/Python-3.7+-3776AB?style=for-the-badge&logo=python&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![License](https://img.shields.io/badge/License-Educational-blue?style=for-the-badge)

**A comprehensive inventory management system for prepared/frozen meals manufacturers**

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Demo](#-demo)

</div>

---

## 📋 Table of Contents

- [About](#-about)
- [Team Members](#-team-members)
- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Database Schema](#-database-schema)
- [Demo Instructions](#-demo-instructions)
- [Project Structure](#-project-structure)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 About

This project implements a **production-ready inventory management system** for a prepared/frozen meals manufacturer. The system provides comprehensive functionality for managing products, ingredients, suppliers, manufacturers, batches, and production workflows with robust database constraints and business logic enforcement.

![Status](https://img.shields.io/badge/Status-Complete-success?style=flat-square)
![Version](https://img.shields.io/badge/Version-1.0.0-blue?style=flat-square)
![Database](https://img.shields.io/badge/Database-MySQL%20%7C%20MariaDB-orange?style=flat-square)

---

## 👥 Team Members

| Member Name                | Unity ID |
| -------------------------- | -------- |
| Pranav V                   | pvarney  |
| Christopher Dillon Michels | Cdmichel |
| Anandteertha Ramesh Rao    | arrao6   |
| Edward Feng                | sfeng9   |

---

## ✨ Features

### 🔐 Role-Based Access Control

![Manufacturer](https://img.shields.io/badge/Role-Manufacturer-blue?style=flat-square)
![Supplier](https://img.shields.io/badge/Role-Supplier-green?style=flat-square)
![Viewer](https://img.shields.io/badge/Role-Viewer-purple?style=flat-square)

#### 👨‍🏭 Manufacturer Features
- ✅ Create and manage product types with categories
- ✅ Versioned recipe plans (BOM) management
- ✅ Record ingredient receipts with validation
- ✅ Create product batches with ingredient consumption
- ✅ **FEFO (First Expired First Out)** lot selection 🎓
- ✅ Inventory reports (on-hand, nearly out of stock, almost expired)
- ✅ Batch cost calculation and summaries
- ✅ **Recall & traceability** system 🎓

#### 🏪 Supplier Features
- ✅ Manage ingredients supplied
- ✅ Create/update ingredient definitions (atomic or compound)
- ✅ Maintain ingredient formulations with versioning
- ✅ **Do-not-combine list** management 🎓
- ✅ Receive ingredient batches with automatic lot numbering

#### 👁️ General Viewer Features
- ✅ Browse available products by category
- ✅ Generate flattened ingredient lists for products
- ✅ **Compare products for incompatibilities** 🎓

#### 📊 Query System
- ✅ 5 pre-defined analytical queries
- ✅ Supplier spending analysis
- ✅ Product cost analysis
- ✅ Ingredient conflict detection

### 🎓 Graduate Features

![Grad](https://img.shields.io/badge/Feature-Graduate%20Level-yellow?style=flat-square)

- **FEFO (First Expired First Out)**: Automatic lot selection prioritizing earliest expiring batches
- **Recall & Traceability**: Track affected product batches for ingredient recalls
- **Incompatibility Checking**: Real-time conflict detection during recipe creation
- **Product Comparison**: Compare products for ingredient incompatibilities

---

## 🛠️ Tech Stack

![Python](https://img.shields.io/badge/Python-3.7+-3776AB?style=flat-square&logo=python&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.0+-4479A1?style=flat-square&logo=mysql&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-10.0+-003545?style=flat-square&logo=mariadb&logoColor=white)

- **Backend**: Python 3.7+
- **Database**: MySQL/MariaDB
- **Database Driver**: mysql-connector-python
- **Environment Management**: python-dotenv
- **Interface**: Menu-driven CLI

---

## 📦 Installation

### Prerequisites

![Requirements](https://img.shields.io/badge/Requirements-Check-green?style=flat-square)

- Python 3.7 or higher
- MySQL/MariaDB database server (8.0+)
- MySQL command-line client (for database setup)

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd database-management-system
```

### Step 2: Install Dependencies

```bash
pip install -r requirements.txt
```

Or install manually:

```bash
pip install mysql-connector-python python-dotenv
```

### Step 3: Database Setup

#### Option A: Using the Application (Recommended)

1. Run the application:
   ```bash
   python main.py
   ```

2. Select option **5. Database Setup (Drop & Recreate)**

3. Type `YES` to confirm

The script will automatically:
- Drop existing database (if any)
- Create fresh database
- Load all schema, triggers, and procedures
- Insert sample data

#### Option B: Manual Setup

```bash
# Create database
mysql -u root -p -e "CREATE DATABASE inventory_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Load schema and data
mysql -u root -p inventory_management < inventory-management.sql
mysql -u root -p inventory_management < triggers.sql
mysql -u root -p inventory_management < stored_procedures.sql
mysql -u root -p inventory_management < sample-data.sql
```

---

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in the project root:

```env
DB_HOST=localhost
DB_NAME=inventory_management
DB_USER=root
DB_PASSWORD=your_password
DB_PORT=3306
```

> ⚠️ **Note**: The `.env` file is gitignored. Never commit database credentials!

![Security](https://img.shields.io/badge/Security-Environment%20Variables-red?style=flat-square)

---

## 🚀 Usage

### Running the Application

```bash
python main.py
```

### Main Menu Options

1. **Manufacturer** - Product and batch management
2. **Supplier** - Ingredient and formulation management
3. **General (Viewer)** - Browse products and view ingredient lists
4. **View Queries** - Execute pre-defined analytical queries
5. **Database Setup** - Drop and recreate database (⚠️ destructive)

### Example Workflow

```bash
# 1. Start application
python main.py

# 2. Select role (e.g., Manufacturer)
# 3. Enter user ID (e.g., MFG001)
# 4. Navigate through menu options
```

---

## 🗄️ Database Schema

### Core Tables

| Table                       | Description                               |
| --------------------------- | ----------------------------------------- |
| `UserDetails`               | User accounts with role-based access      |
| `Product`                   | Product definitions with categories       |
| `Ingredient`                | Atomic and compound ingredients           |
| `IngredientFormulation`     | Supplier-specific ingredient formulations |
| `ProductBOM`                | Bill of materials for products            |
| `RecipePlan`                | Versioned recipe plans                    |
| `IngredientBatch`           | Ingredient inventory batches              |
| `ProductBatch`              | Production batches                        |
| `IngredientConsumption`     | Ingredient consumption tracking           |
| `IngredientIncompatibility` | Ingredient conflict rules                 |

### Stored Procedures

![Procedures](https://img.shields.io/badge/Procedures-4-blue?style=flat-square)

- `RecordProductionBatch` - Creates product batch with validation
- `RecordIngredientIntake` - Records ingredient batch intake
- `ConsumeIngredientLot` - Consumes ingredient lots into product batches
- `RecalculateBatchCost` - Recalculates batch costs

### Triggers

![Triggers](https://img.shields.io/badge/Triggers-10-green?style=flat-square)

- Auto-generate ingredient lot numbers
- Enforce 90-day expiration rule
- Prevent expired consumption
- Maintain inventory on-hand quantities
- Role validation for manufacturers and suppliers

---

## 🎬 Demo Instructions

### Test Users

| Role         | User ID  | Name             |
| ------------ | -------- | ---------------- |
| Manufacturer | `MFG001` | Manufacturer One |
| Manufacturer | `MFG002` | Manufacturer Two |
| Supplier     | `20`     | SupplierA Inc.   |
| Supplier     | `21`     | SupplierB Co.    |

### Demo Scenarios

#### 1. Manufacturer Demo (MFG001)

```
1. Login as Manufacturer → Enter ID: MFG001
2. Products → Create/Update
3. Products → Recipe Plans
4. Production → Create Product Batch
5. Reports → View all reports
6. (Grad) Recall & Traceability
```

#### 2. Supplier Demo (20)

```
1. Login as Supplier → Enter ID: 20
2. Manage Ingredients Supplied
3. Ingredients → Create/Update
4. Ingredients → Do-Not-Combine
5. Inventory → Receive Ingredient Batch
```

#### 3. General Viewer Demo

```
1. Login as General Viewer
2. Browse Products
3. Product → Ingredient List
4. (Grad) Compare Products
```

#### 4. Queries Demo

```
1. Select "View Queries"
2. Execute all 5 required queries:
   - Query 1: Last batch ingredients
   - Query 2: Supplier spending analysis
   - Query 3: Unit cost lookup
   - Query 4: Conflict detection
   - Query 5: Supplier coverage analysis
```

---

## 📁 Project Structure

```
database-management-system/
├── 📄 main.py                    # Main entry point
├── 📄 database.py                # Database connection & operations
├── 📄 database_setup.py          # Database setup script
├── 📄 manufacturer.py             # Manufacturer role functionality
├── 📄 supplier.py                # Supplier role functionality
├── 📄 general_viewer.py          # General viewer functionality
├── 📄 queries.py                 # Required queries
├── 📄 enums.py                   # Enumerations
├── 📄 requirements.txt           # Python dependencies
├── 📄 .env                       # Environment variables (gitignored)
├── 📄 .gitignore                 # Git ignore rules
├── 📄 README.md                  # This file
│
├── 🗄️ inventory-management.sql   # Database schema
├── 🗄️ triggers.sql               # Database triggers
├── 🗄️ stored_procedures.sql      # Stored procedures
└── 🗄️ sample-data.sql            # Sample data
```

---

## 🔍 Required Queries

![Queries](https://img.shields.io/badge/Queries-5-blue?style=flat-square)

1. **Last Batch Ingredients**: List ingredients and lot numbers of last batch of Steak Dinner (100) by MFG001
2. **Supplier Spending**: For MFG002, list all suppliers and total amount spent
3. **Unit Cost**: Find unit cost for product lot 100-MFG001-B0901
4. **Conflict Detection**: Find conflicting ingredients for product lot 100-MFG001-B0901
5. **Supplier Coverage**: Which manufacturers has supplier James Miller (21) NOT supplied to?

---

## 🐛 Troubleshooting

### Database Connection Error

![Error](https://img.shields.io/badge/Issue-Connection-red?style=flat-square)

- ✅ Check `.env` file configuration
- ✅ Verify database server is running
- ✅ Ensure database exists and user has proper permissions
- ✅ Test connection: `mysql -u root -p -h localhost`

### Import Errors

![Error](https://img.shields.io/badge/Issue-Import-red?style=flat-square)

- ✅ Install dependencies: `pip install -r requirements.txt`
- ✅ Verify Python version: `python --version` (should be 3.7+)
- ✅ Check virtual environment activation

### SQL Errors

![Error](https://img.shields.io/badge/Issue-SQL-red?style=flat-square)

- ✅ Verify all SQL files executed in order
- ✅ Check database setup completed successfully
- ✅ Verify sample data loaded correctly
- ✅ Use Database Setup option (option 5) to recreate

### Tables Not Created

![Error](https://img.shields.io/badge/Issue-Schema-red?style=flat-square)

- ✅ Run Database Setup from main menu (option 5)
- ✅ Check MySQL command-line client is installed
- ✅ Verify SQL files are in project directory
- ✅ Check file permissions

---

## 📝 Notes

- 🖥️ **Interface**: Menu-driven CLI (no GUI)
- 🔒 **Constraints**: Enforced via triggers and stored procedures
- 🎓 **Grad Features**: FEFO, recall/traceability, incompatibility checking
- 🔄 **Composition**: Supports one-level compound ingredient composition
- ✅ **Validation**: All business rules enforced at database level

---

## 📄 License

![License](https://img.shields.io/badge/License-Educational-blue?style=flat-square)

This project is for **educational purposes** (CSC540 - Project 1).

---

## 🙏 Acknowledgments

- **Course**: CSC540 - Database Management Systems
- **Institution**: North Carolina State University
- **Project**: Inventory Management for Prepared/Frozen Meals Manufacturer

---

<div align="center">

**Made with ❤️ by Team CSC540**

![Status](https://img.shields.io/badge/Status-Production%20Ready-success?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-1.0.0-blue?style=for-the-badge)

</div>
