-- Create a new database
CREATE DATABASE SalesDB;
USE SalesDB;

-- Create Customers table
CREATE TABLE Customers (
    CustomerID INT AUTO_INCREMENT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE,
    Phone VARCHAR(20)
);

-- Create Products table
CREATE TABLE Products (
    ProductID INT AUTO_INCREMENT PRIMARY KEY,
    ProductName VARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    Stock INT DEFAULT 0
);

-- Create Orders table
CREATE TABLE Orders (
    OrderID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    TotalAmount DECIMAL(10,2),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

-- Create OrderDetails table
CREATE TABLE OrderDetails (
    OrderDetailID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);
INSERT INTO Customers (FirstName, LastName, Email, Phone)
VALUES ('Vidhi', 'Sharma', 'vidhi@example.com', '9876543210');

INSERT INTO Products (ProductName, Price, Stock)
VALUES ('Laptop', 75000.00, 10),
       ('Smartphone', 25000.00, 20),
       ('Headphones', 1500.00, 50);

INSERT INTO Orders (CustomerID, TotalAmount)
VALUES (1, 25000.00);

INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
VALUES (1, 2, 1, 25000.00);

# Full database backup
mysqldump -u root -p SalesDB > /backups/SalesDB_backup.sql

# Create the database if not exists
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS SalesDB;"
# Restore data from backup file
mysql -u root -p SalesDB < /backups/SalesDB_backup.sql