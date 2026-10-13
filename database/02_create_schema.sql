/*
  02_create_schema.sql
  Creates the dbo tables, constraints and indexes. Only runs against an empty CaldovaOrderManagement database.
  Inferred design: see README.md in this folder.
*/
USE CaldovaOrderManagement;
GO
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

IF EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID(N'dbo'))
    RAISERROR(N'The database already contains tables. Schema script not run.', 16, 1);
GO

CREATE TABLE dbo.ProductCategories (
    CategoryID    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProductCategories PRIMARY KEY,
    CategoryName  NVARCHAR(100) NOT NULL CONSTRAINT UQ_ProductCategories_Name UNIQUE,
    Description   NVARCHAR(500) NULL
);

CREATE TABLE dbo.ProductCatalog (
    ProductID     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProductCatalog PRIMARY KEY,
    CategoryID    INT NOT NULL CONSTRAINT FK_ProductCatalog_Category REFERENCES dbo.ProductCategories(CategoryID),
    SKU           NVARCHAR(40)  NOT NULL CONSTRAINT UQ_ProductCatalog_SKU UNIQUE,
    ProductName   NVARCHAR(150) NOT NULL,
    UnitPrice     DECIMAL(10,2) NOT NULL CONSTRAINT CK_ProductCatalog_UnitPrice CHECK (UnitPrice >= 0),
    IsActive      BIT NOT NULL CONSTRAINT DF_ProductCatalog_IsActive DEFAULT (1),
    CreatedDate   DATETIME2(0) NOT NULL CONSTRAINT DF_ProductCatalog_Created DEFAULT (SYSDATETIME()),
    ModifiedDate  DATETIME2(0) NOT NULL CONSTRAINT DF_ProductCatalog_Modified DEFAULT (SYSDATETIME())
);
CREATE INDEX IX_ProductCatalog_CategoryID ON dbo.ProductCatalog(CategoryID);
CREATE INDEX IX_ProductCatalog_ProductName ON dbo.ProductCatalog(ProductName);

CREATE TABLE dbo.ProductDescriptions (
    ProductDescriptionID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProductDescriptions PRIMARY KEY,
    ProductID       INT NOT NULL CONSTRAINT FK_ProductDescriptions_Product REFERENCES dbo.ProductCatalog(ProductID),
    LanguageCode    NVARCHAR(10)  NOT NULL CONSTRAINT DF_ProductDescriptions_Language DEFAULT (N'en-US'),
    ShortDescription NVARCHAR(300) NOT NULL,
    LongDescription NVARCHAR(2000) NOT NULL,
    Specifications  NVARCHAR(1000) NULL,
    CreatedDate     DATETIME2(0) NOT NULL CONSTRAINT DF_ProductDescriptions_Created DEFAULT (SYSDATETIME()),
    ModifiedDate    DATETIME2(0) NOT NULL CONSTRAINT DF_ProductDescriptions_Modified DEFAULT (SYSDATETIME()),
    CONSTRAINT UQ_ProductDescriptions_ProductLanguage UNIQUE (ProductID, LanguageCode)
);

CREATE TABLE dbo.Inventory (
    InventoryID      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Inventory PRIMARY KEY,
    ProductID        INT NOT NULL CONSTRAINT FK_Inventory_Product REFERENCES dbo.ProductCatalog(ProductID),
    LocationName     NVARCHAR(100) NOT NULL,
    QuantityOnHand   INT NOT NULL CONSTRAINT CK_Inventory_OnHand CHECK (QuantityOnHand >= 0),
    QuantityReserved INT NOT NULL CONSTRAINT DF_Inventory_Reserved DEFAULT (0) CONSTRAINT CK_Inventory_Reserved CHECK (QuantityReserved >= 0),
    ReorderLevel     INT NOT NULL CONSTRAINT DF_Inventory_Reorder DEFAULT (0) CONSTRAINT CK_Inventory_Reorder CHECK (ReorderLevel >= 0),
    ModifiedDate     DATETIME2(0) NOT NULL CONSTRAINT DF_Inventory_Modified DEFAULT (SYSDATETIME()),
    CONSTRAINT CK_Inventory_AvailableNonNegative CHECK (QuantityReserved <= QuantityOnHand),
    CONSTRAINT UQ_Inventory_ProductLocation UNIQUE (ProductID, LocationName)
);

CREATE TABLE dbo.Customers (
    CustomerID   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
    CustomerName NVARCHAR(150) NOT NULL,
    Email        NVARCHAR(254) NULL,
    Phone        NVARCHAR(30)  NULL,
    IsActive     BIT NOT NULL CONSTRAINT DF_Customers_IsActive DEFAULT (1),
    CreatedDate  DATETIME2(0) NOT NULL CONSTRAINT DF_Customers_Created DEFAULT (SYSDATETIME()),
    ModifiedDate DATETIME2(0) NOT NULL CONSTRAINT DF_Customers_Modified DEFAULT (SYSDATETIME())
);
CREATE INDEX IX_Customers_CustomerName ON dbo.Customers(CustomerName);
CREATE UNIQUE INDEX UX_Customers_Email ON dbo.Customers(Email) WHERE Email IS NOT NULL;

CREATE TABLE dbo.CustomerAddresses (
    AddressID     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CustomerAddresses PRIMARY KEY,
    CustomerID    INT NOT NULL CONSTRAINT FK_CustomerAddresses_Customer REFERENCES dbo.Customers(CustomerID),
    AddressType   NVARCHAR(20)  NOT NULL CONSTRAINT CK_CustomerAddresses_Type CHECK (AddressType IN (N'Billing', N'Shipping')),
    AddressLine1  NVARCHAR(200) NOT NULL,
    AddressLine2  NVARCHAR(200) NULL,
    City          NVARCHAR(100) NOT NULL,
    StateProvince NVARCHAR(100) NULL,
    PostalCode    NVARCHAR(20)  NULL,
    Country       NVARCHAR(100) NOT NULL,
    -- Lets Orders reference an address together with its customer so an order cannot use another customer's address.
    CONSTRAINT UQ_CustomerAddresses_AddressCustomer UNIQUE (AddressID, CustomerID)
);
CREATE INDEX IX_CustomerAddresses_CustomerID ON dbo.CustomerAddresses(CustomerID);

CREATE TABLE dbo.Orders (
    OrderID           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerID        INT NOT NULL CONSTRAINT FK_Orders_Customer REFERENCES dbo.Customers(CustomerID),
    OrderDate         DATETIME2(0) NOT NULL CONSTRAINT DF_Orders_OrderDate DEFAULT (SYSDATETIME()),
    Status            NVARCHAR(30) NOT NULL CONSTRAINT DF_Orders_Status DEFAULT (N'Pending')
        CONSTRAINT CK_Orders_Status CHECK (Status IN (N'Pending', N'Processing', N'Confirmed', N'PartiallyShipped', N'Shipped', N'Delivered', N'Cancelled')),
    BillingAddressID  INT NULL,
    ShippingAddressID INT NULL,
    ModifiedDate      DATETIME2(0) NOT NULL CONSTRAINT DF_Orders_Modified DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Orders_BillingAddress  FOREIGN KEY (BillingAddressID,  CustomerID) REFERENCES dbo.CustomerAddresses(AddressID, CustomerID),
    CONSTRAINT FK_Orders_ShippingAddress FOREIGN KEY (ShippingAddressID, CustomerID) REFERENCES dbo.CustomerAddresses(AddressID, CustomerID)
);
CREATE INDEX IX_Orders_CustomerID ON dbo.Orders(CustomerID);
CREATE INDEX IX_Orders_Status ON dbo.Orders(Status);
CREATE INDEX IX_Orders_OrderDate ON dbo.Orders(OrderDate);

CREATE TABLE dbo.OrderLines (
    OrderLineID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderLines PRIMARY KEY,
    OrderID     INT NOT NULL CONSTRAINT FK_OrderLines_Order REFERENCES dbo.Orders(OrderID),
    ProductID   INT NOT NULL CONSTRAINT FK_OrderLines_Product REFERENCES dbo.ProductCatalog(ProductID),
    Quantity    INT NOT NULL CONSTRAINT CK_OrderLines_Quantity CHECK (Quantity > 0),
    UnitPrice   DECIMAL(10,2) NOT NULL CONSTRAINT CK_OrderLines_UnitPrice CHECK (UnitPrice >= 0),
    CONSTRAINT UQ_OrderLines_OrderProduct UNIQUE (OrderID, ProductID)
);
CREATE INDEX IX_OrderLines_ProductID ON dbo.OrderLines(ProductID);

CREATE TABLE dbo.Shipments (
    ShipmentID     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Shipments PRIMARY KEY,
    OrderID        INT NOT NULL CONSTRAINT FK_Shipments_Order REFERENCES dbo.Orders(OrderID),
    ShipmentDate   DATETIME2(0) NULL,
    Carrier        NVARCHAR(100) NULL,
    TrackingNumber NVARCHAR(60)  NULL,
    Status         NVARCHAR(30) NOT NULL CONSTRAINT DF_Shipments_Status DEFAULT (N'Pending')
        CONSTRAINT CK_Shipments_Status CHECK (Status IN (N'Pending', N'Processing', N'Shipped', N'Delivered', N'Cancelled')),
    DeliveredDate  DATETIME2(0) NULL,
    CONSTRAINT CK_Shipments_Dates CHECK (DeliveredDate IS NULL OR (ShipmentDate IS NOT NULL AND DeliveredDate >= ShipmentDate)),
    CONSTRAINT CK_Shipments_StatusDates CHECK (
        (Status NOT IN (N'Shipped', N'Delivered') OR ShipmentDate IS NOT NULL)
        AND (Status <> N'Delivered' OR DeliveredDate IS NOT NULL))
);
CREATE INDEX IX_Shipments_OrderID ON dbo.Shipments(OrderID);
CREATE INDEX IX_Shipments_Status ON dbo.Shipments(Status);
CREATE UNIQUE INDEX UX_Shipments_Tracking ON dbo.Shipments(TrackingNumber) WHERE TrackingNumber IS NOT NULL;
GO

PRINT 'Schema created.';
GO
