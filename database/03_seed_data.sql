/*
  03_seed_data.sql
  DEMONSTRATION DATA ONLY. Product names are well-known tablet brands used as recognizable examples;
  SKUs, prices, stock levels, customers, orders and shipments are fictional. Nothing here is medical advice,
  real inventory, or current market pricing.
  Runs only when dbo.ProductCatalog is empty. Everything runs in one transaction.
*/
USE CaldovaOrderManagement;
GO
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (SELECT 1 FROM dbo.ProductCatalog) OR EXISTS (SELECT 1 FROM dbo.Customers)
BEGIN
    RAISERROR(N'Seed data not loaded: tables already contain data.', 16, 1);
    RETURN;
END

BEGIN TRANSACTION;

-- Categories
INSERT dbo.ProductCategories (CategoryName, Description) VALUES
 (N'Pain Relief & Fever',      N'Analgesic and antipyretic tablets (demo catalogue category).'),
 (N'Allergy & Cold',           N'Antihistamine and cold-symptom tablets (demo catalogue category).'),
 (N'Gastrointestinal',         N'Antacid and stomach-care tablets (demo catalogue category).'),
 (N'Antibiotics',              N'Antibacterial tablets, shown for demonstration only (demo catalogue category).'),
 (N'Vitamins & Supplements',   N'Vitamin, mineral and supplement tablets (demo catalogue category).'),
 (N'Cardiac & Diabetes Care',  N'Cardiovascular and blood-sugar care tablets (demo catalogue category).');

-- Products: SKU, name, category, price, active ingredient(s), pack, therapeutic area
CREATE TABLE #p (SKU NVARCHAR(40), Name NVARCHAR(150), Cat NVARCHAR(100), Price DECIMAL(10,2), Ingredient NVARCHAR(200),
                 Pack NVARCHAR(60), Area NVARCHAR(120), Active BIT);
INSERT #p VALUES
 (N'CAL-PN-001', N'Paracetamol 500mg Tablets', N'Pain Relief & Fever', 18.50,  N'Paracetamol 500 mg', N'strip of 10 tablets', N'fever and mild pain', 1),
 (N'CAL-PN-002', N'Dolo 650',                  N'Pain Relief & Fever', 31.00,  N'Paracetamol 650 mg', N'strip of 15 tablets', N'fever and mild pain', 1),
 (N'CAL-PN-003', N'Crocin Advance 500',        N'Pain Relief & Fever', 22.00,  N'Paracetamol 500 mg', N'strip of 15 tablets', N'fever and headache', 1),
 (N'CAL-PN-004', N'Calpol 500',                N'Pain Relief & Fever', 19.50,  N'Paracetamol 500 mg', N'strip of 15 tablets', N'fever and mild pain', 1),
 (N'CAL-PN-005', N'Saridon',                   N'Pain Relief & Fever', 42.00,  N'Paracetamol, Propyphenazone and Caffeine', N'strip of 10 tablets', N'headache', 1),
 (N'CAL-PN-006', N'Zerodol-P',                 N'Pain Relief & Fever', 98.00,  N'Aceclofenac and Paracetamol', N'strip of 10 tablets', N'pain and inflammation', 1),
 (N'CAL-PN-007', N'Zerodol-SP',                N'Pain Relief & Fever', 135.00, N'Aceclofenac, Paracetamol and Serratiopeptidase', N'strip of 10 tablets', N'pain and swelling', 1),
 (N'CAL-PN-008', N'Combiflam',                 N'Pain Relief & Fever', 49.00,  N'Ibuprofen and Paracetamol', N'strip of 20 tablets', N'pain and fever', 1),
 (N'CAL-PN-009', N'Brufen 400',                N'Pain Relief & Fever', 28.00,  N'Ibuprofen 400 mg', N'strip of 15 tablets', N'pain and inflammation', 1),
 (N'CAL-AC-001', N'Cetirizine 10mg Tablets',   N'Allergy & Cold',      24.00,  N'Cetirizine 10 mg', N'strip of 10 tablets', N'allergy symptoms', 1),
 (N'CAL-AC-002', N'Allegra 120',               N'Allergy & Cold',      215.00, N'Fexofenadine 120 mg', N'strip of 10 tablets', N'allergy symptoms', 1),
 (N'CAL-AC-003', N'Montair LC',                N'Allergy & Cold',      175.00, N'Montelukast and Levocetirizine', N'strip of 10 tablets', N'allergy and cold symptoms', 1),
 (N'CAL-AC-004', N'Avil 25',                   N'Allergy & Cold',      12.00,  N'Pheniramine 25 mg', N'strip of 15 tablets', N'allergy symptoms', 1),
 (N'CAL-AC-005', N'Sinarest',                  N'Allergy & Cold',      58.00,  N'Paracetamol, Phenylephrine and Chlorpheniramine', N'strip of 10 tablets', N'cold and congestion', 1),
 (N'CAL-GI-001', N'Pantop 40',                 N'Gastrointestinal',    148.00, N'Pantoprazole 40 mg', N'strip of 15 tablets', N'acidity and reflux', 1),
 (N'CAL-GI-002', N'Digene',                    N'Gastrointestinal',    22.00,  N'Antacid combination (chewable)', N'strip of 15 tablets', N'acidity and gas', 1),
 (N'CAL-GI-003', N'Rantac 150',                N'Gastrointestinal',    31.00,  N'Ranitidine 150 mg', N'strip of 30 tablets', N'acidity (discontinued demo item)', 0),
 (N'CAL-GI-004', N'Gelusil MPS',               N'Gastrointestinal',    38.00,  N'Antacid combination (chewable)', N'strip of 20 tablets', N'acidity and bloating', 1),
 (N'CAL-GI-005', N'Domstal 10mg',              N'Gastrointestinal',    38.00,  N'Domperidone 10 mg', N'strip of 10 tablets', N'nausea and stomach upset', 1),
 (N'CAL-AB-001', N'Azithral 500',              N'Antibiotics',         119.00, N'Azithromycin 500 mg', N'strip of 5 tablets', N'bacterial infections (demo)', 1),
 (N'CAL-AB-002', N'Augmentin 625',             N'Antibiotics',         224.00, N'Amoxicillin and Clavulanic Acid', N'strip of 10 tablets', N'bacterial infections (demo)', 1),
 (N'CAL-AB-003', N'Taxim-O 200',               N'Antibiotics',         112.00, N'Cefixime 200 mg', N'strip of 10 tablets', N'bacterial infections (demo)', 1),
 (N'CAL-AB-004', N'Cifran 500',                N'Antibiotics',         85.00,  N'Ciprofloxacin 500 mg', N'strip of 10 tablets', N'bacterial infections (demo)', 1),
 (N'CAL-VT-001', N'Shelcal 500',               N'Vitamins & Supplements', 118.00, N'Calcium and Vitamin D3', N'strip of 15 tablets', N'bone health supplement', 1),
 (N'CAL-VT-002', N'Limcee 500 Chewable',       N'Vitamins & Supplements', 25.00,  N'Vitamin C 500 mg', N'strip of 15 tablets', N'vitamin C supplement', 1),
 (N'CAL-VT-003', N'Neurobion Forte',           N'Vitamins & Supplements', 38.00,  N'Vitamin B-complex', N'strip of 30 tablets', N'B-vitamin supplement', 1),
 (N'CAL-VT-004', N'Zincovit',                  N'Vitamins & Supplements', 105.00, N'Multivitamin, multimineral and Zinc', N'strip of 15 tablets', N'multivitamin supplement', 1),
 (N'CAL-CD-001', N'Ecosprin 75',               N'Cardiac & Diabetes Care', 7.50,   N'Aspirin 75 mg', N'strip of 14 tablets', N'cardiac care', 1),
 (N'CAL-CD-002', N'Glycomet 500',              N'Cardiac & Diabetes Care', 26.00,  N'Metformin 500 mg', N'strip of 20 tablets', N'blood sugar care', 1),
 (N'CAL-CD-003', N'Telma 40',                  N'Cardiac & Diabetes Care', 138.00, N'Telmisartan 40 mg', N'strip of 15 tablets', N'blood pressure care', 1),
 (N'CAL-CD-004', N'Amlokind 5',                N'Cardiac & Diabetes Care', 42.00,  N'Amlodipine 5 mg', N'strip of 10 tablets', N'blood pressure care', 1);

INSERT dbo.ProductCatalog (CategoryID, SKU, ProductName, UnitPrice, IsActive, CreatedDate, ModifiedDate)
SELECT c.CategoryID, p.SKU, p.Name, p.Price, p.Active, DATEADD(DAY, -120, SYSDATETIME()), DATEADD(DAY, -10, SYSDATETIME())
FROM #p p JOIN dbo.ProductCategories c ON c.CategoryName = p.Cat
ORDER BY p.SKU;

-- Two searchable descriptions per product
INSERT dbo.ProductDescriptions (ProductID, DescriptionType, DescriptionText)
SELECT pc.ProductID, N'Overview',
       CONCAT(p.Name, N' tablets containing ', p.Ingredient, N'. Catalogue category: ', p.Area,
              N'. Demonstration text only; not medical advice.')
FROM #p p JOIN dbo.ProductCatalog pc ON pc.SKU = p.SKU
UNION ALL
SELECT pc.ProductID, N'Packaging',
       CONCAT(p.Name, N' is supplied as a ', p.Pack, N'. Store in a cool, dry place away from direct sunlight (sample catalogue text).')
FROM #p p JOIN dbo.ProductCatalog pc ON pc.SKU = p.SKU;

-- Inventory: SKU, location, on hand, reserved, reorder level (demo values, varied on purpose)
CREATE TABLE #i (SKU NVARCHAR(40), Loc NVARCHAR(100), OnHand INT, Reserved INT, Reorder INT);
INSERT #i VALUES
 (N'CAL-PN-001', N'Mumbai DC', 800, 60, 200), (N'CAL-PN-001', N'Delhi DC', 500, 40, 150),
 (N'CAL-PN-002', N'Mumbai DC', 1200, 150, 300), (N'CAL-PN-002', N'Bengaluru DC', 900, 80, 250), (N'CAL-PN-002', N'Delhi DC', 700, 90, 200),
 (N'CAL-PN-003', N'Mumbai DC', 600, 50, 200), (N'CAL-PN-003', N'Delhi DC', 450, 30, 150),
 (N'CAL-PN-004', N'Mumbai DC', 90, 20, 150),
 (N'CAL-PN-005', N'Mumbai DC', 40, 40, 100), (N'CAL-PN-005', N'Delhi DC', 10, 10, 50),
 (N'CAL-PN-006', N'Mumbai DC', 300, 40, 100), (N'CAL-PN-006', N'Bengaluru DC', 220, 20, 80),
 (N'CAL-PN-007', N'Mumbai DC', 150, 30, 60), (N'CAL-PN-007', N'Delhi DC', 60, 10, 40),
 (N'CAL-PN-008', N'Mumbai DC', 700, 70, 200), (N'CAL-PN-008', N'Delhi DC', 400, 20, 150), (N'CAL-PN-008', N'Bengaluru DC', 300, 10, 100),
 (N'CAL-PN-009', N'Mumbai DC', 120, 10, 100), (N'CAL-PN-009', N'Delhi DC', 40, 5, 50),
 (N'CAL-AC-001', N'Mumbai DC', 500, 40, 150), (N'CAL-AC-001', N'Bengaluru DC', 350, 10, 100),
 (N'CAL-AC-002', N'Mumbai DC', 80, 10, 40), (N'CAL-AC-002', N'Delhi DC', 60, 5, 30),
 (N'CAL-AC-003', N'Mumbai DC', 25, 25, 30), (N'CAL-AC-003', N'Delhi DC', 10, 10, 20),
 (N'CAL-AC-004', N'Mumbai DC', 900, 20, 200),
 (N'CAL-AC-005', N'Mumbai DC', 260, 60, 120), (N'CAL-AC-005', N'Bengaluru DC', 80, 10, 60),
 (N'CAL-GI-001', N'Mumbai DC', 400, 50, 100), (N'CAL-GI-001', N'Delhi DC', 300, 30, 100), (N'CAL-GI-001', N'Bengaluru DC', 250, 20, 80),
 (N'CAL-GI-002', N'Mumbai DC', 350, 30, 100), (N'CAL-GI-002', N'Delhi DC', 200, 10, 100),
 (N'CAL-GI-003', N'Mumbai DC', 0, 0, 50),
 (N'CAL-GI-004', N'Mumbai DC', 140, 20, 80),
 (N'CAL-GI-005', N'Mumbai DC', 60, 15, 60), (N'CAL-GI-005', N'Delhi DC', 40, 10, 40),
 (N'CAL-AB-001', N'Mumbai DC', 120, 20, 50), (N'CAL-AB-001', N'Delhi DC', 90, 10, 40),
 (N'CAL-AB-002', N'Mumbai DC', 70, 20, 40), (N'CAL-AB-002', N'Bengaluru DC', 30, 10, 30),
 (N'CAL-AB-003', N'Mumbai DC', 55, 5, 30), (N'CAL-AB-003', N'Delhi DC', 45, 5, 30),
 (N'CAL-AB-004', N'Mumbai DC', 0, 0, 40), (N'CAL-AB-004', N'Delhi DC', 0, 0, 40),
 (N'CAL-VT-001', N'Mumbai DC', 300, 20, 100), (N'CAL-VT-001', N'Delhi DC', 200, 10, 80),
 (N'CAL-VT-002', N'Mumbai DC', 600, 30, 150),
 (N'CAL-VT-003', N'Mumbai DC', 180, 20, 80), (N'CAL-VT-003', N'Bengaluru DC', 120, 10, 60),
 (N'CAL-VT-004', N'Mumbai DC', 15, 5, 50),
 (N'CAL-CD-001', N'Mumbai DC', 1500, 100, 400), (N'CAL-CD-001', N'Delhi DC', 1000, 50, 300),
 (N'CAL-CD-002', N'Mumbai DC', 650, 60, 200), (N'CAL-CD-002', N'Bengaluru DC', 400, 40, 150),
 (N'CAL-CD-003', N'Mumbai DC', 160, 20, 60), (N'CAL-CD-003', N'Delhi DC', 90, 10, 50),
 (N'CAL-CD-004', N'Mumbai DC', 210, 20, 80), (N'CAL-CD-004', N'Bengaluru DC', 130, 10, 60);

INSERT dbo.Inventory (ProductID, LocationName, QuantityOnHand, QuantityReserved, ReorderLevel, ModifiedDate)
SELECT pc.ProductID, i.Loc, i.OnHand, i.Reserved, i.Reorder, DATEADD(DAY, -2, SYSDATETIME())
FROM #i i JOIN dbo.ProductCatalog pc ON pc.SKU = i.SKU;

-- Customers (fictional)
INSERT dbo.Customers (CustomerName, Email, Phone, IsActive, CreatedDate, ModifiedDate) VALUES
 (N'Sunrise Pharmacy',            N'orders@sunrise-pharmacy.example.com',  N'+91 90000 10001', 1, DATEADD(DAY,-200,SYSDATETIME()), DATEADD(DAY,-20,SYSDATETIME())),
 (N'Greenleaf Medical Store',     N'purchasing@greenleaf-med.example.com', N'+91 90000 10002', 1, DATEADD(DAY,-190,SYSDATETIME()), DATEADD(DAY,-30,SYSDATETIME())),
 (N'Lakeview Clinic',             N'admin@lakeview-clinic.example.com',    N'+91 90000 10003', 1, DATEADD(DAY,-180,SYSDATETIME()), DATEADD(DAY,-15,SYSDATETIME())),
 (N'Metro Wellness Chemist',      N'supply@metrowellness.example.com',     N'+91 90000 10004', 1, DATEADD(DAY,-170,SYSDATETIME()), DATEADD(DAY,-12,SYSDATETIME())),
 (N'Harbor Health Pharmacy',      N'buying@harborhealth.example.com',      N'+91 90000 10005', 1, DATEADD(DAY,-160,SYSDATETIME()), DATEADD(DAY,-9,SYSDATETIME())),
 (N'Orchid Care Hospital Stores', N'stores@orchidcare.example.com',        N'+91 90000 10006', 1, DATEADD(DAY,-150,SYSDATETIME()), DATEADD(DAY,-8,SYSDATETIME())),
 (N'Pinecrest Family Pharmacy',   N'hello@pinecrest-pharmacy.example.com', N'+91 90000 10007', 1, DATEADD(DAY,-140,SYSDATETIME()), DATEADD(DAY,-7,SYSDATETIME())),
 (N'Riverside Dispensary',        N'orders@riverside-disp.example.com',    N'+91 90000 10008', 1, DATEADD(DAY,-130,SYSDATETIME()), DATEADD(DAY,-6,SYSDATETIME())),
 (N'Summit Care Pharmacy',        N'procure@summitcare.example.com',       N'+91 90000 10009', 1, DATEADD(DAY,-120,SYSDATETIME()), DATEADD(DAY,-5,SYSDATETIME())),
 (N'Old Town Chemists',           N'contact@oldtown-chemists.example.com', N'+91 90000 10010', 0, DATEADD(DAY,-300,SYSDATETIME()), DATEADD(DAY,-60,SYSDATETIME()));

CREATE TABLE #a (Cust NVARCHAR(150), Typ NVARCHAR(20), L1 NVARCHAR(200), L2 NVARCHAR(200), City NVARCHAR(100), St NVARCHAR(100), Pin NVARCHAR(20));
INSERT #a VALUES
 (N'Sunrise Pharmacy', N'Billing',  N'12 Demo Market Road', N'Shop 4', N'Mumbai', N'Maharashtra', N'400001'),
 (N'Sunrise Pharmacy', N'Shipping', N'12 Demo Market Road', N'Receiving Bay', N'Mumbai', N'Maharashtra', N'400001'),
 (N'Greenleaf Medical Store', N'Billing',  N'45 Sample Avenue', NULL, N'Delhi', N'Delhi', N'110001'),
 (N'Greenleaf Medical Store', N'Shipping', N'88 Example Industrial Area', N'Unit 7', N'Delhi', N'Delhi', N'110020'),
 (N'Greenleaf Medical Store', N'Shipping', N'3 Fictional Warehouse Lane', NULL, N'Gurugram', N'Haryana', N'122001'),
 (N'Lakeview Clinic', N'Billing',  N'7 Lakeside Demo Street', N'Floor 2', N'Bengaluru', N'Karnataka', N'560001'),
 (N'Lakeview Clinic', N'Shipping', N'7 Lakeside Demo Street', N'Clinic Reception', N'Bengaluru', N'Karnataka', N'560001'),
 (N'Metro Wellness Chemist', N'Billing',  N'210 Placeholder Circle', NULL, N'Chennai', N'Tamil Nadu', N'600001'),
 (N'Metro Wellness Chemist', N'Shipping', N'210 Placeholder Circle', N'Goods Entrance', N'Chennai', N'Tamil Nadu', N'600001'),
 (N'Harbor Health Pharmacy', N'Billing',  N'5 Harbor Demo Quay', NULL, N'Kochi', N'Kerala', N'682001'),
 (N'Harbor Health Pharmacy', N'Shipping', N'19 Sample Port Road', N'Dock Office', N'Kochi', N'Kerala', N'682003'),
 (N'Orchid Care Hospital Stores', N'Billing',  N'101 Fictional Hospital Campus', N'Admin Block', N'Pune', N'Maharashtra', N'411001'),
 (N'Orchid Care Hospital Stores', N'Shipping', N'101 Fictional Hospital Campus', N'Central Store', N'Pune', N'Maharashtra', N'411001'),
 (N'Orchid Care Hospital Stores', N'Shipping', N'22 Example Annex Road', N'Satellite Pharmacy', N'Pune', N'Maharashtra', N'411014'),
 (N'Pinecrest Family Pharmacy', N'Billing',  N'66 Pinecrest Demo Lane', NULL, N'Hyderabad', N'Telangana', N'500001'),
 (N'Pinecrest Family Pharmacy', N'Shipping', N'66 Pinecrest Demo Lane', N'Rear Entrance', N'Hyderabad', N'Telangana', N'500001'),
 (N'Riverside Dispensary', N'Billing',  N'8 Riverside Sample Marg', NULL, N'Kolkata', N'West Bengal', N'700001'),
 (N'Riverside Dispensary', N'Shipping', N'8 Riverside Sample Marg', N'Loading Dock', N'Kolkata', N'West Bengal', N'700001'),
 (N'Summit Care Pharmacy', N'Billing',  N'31 Summit Demo Plaza', N'Suite 5', N'Ahmedabad', N'Gujarat', N'380001'),
 (N'Summit Care Pharmacy', N'Shipping', N'31 Summit Demo Plaza', N'Back Gate', N'Ahmedabad', N'Gujarat', N'380001'),
 (N'Old Town Chemists', N'Billing',  N'2 Old Town Placeholder Street', NULL, N'Jaipur', N'Rajasthan', N'302001'),
 (N'Old Town Chemists', N'Shipping', N'2 Old Town Placeholder Street', NULL, N'Jaipur', N'Rajasthan', N'302001');

INSERT dbo.CustomerAddresses (CustomerID, AddressType, AddressLine1, AddressLine2, City, StateProvince, PostalCode, Country)
SELECT c.CustomerID, a.Typ, a.L1, a.L2, a.City, a.St, a.Pin, N'India'
FROM #a a JOIN dbo.Customers c ON c.CustomerName = a.Cust;

-- Orders (explicit IDs so lines and shipments below are deterministic)
CREATE TABLE #o (No INT, Cust NVARCHAR(150), DaysAgo INT, Status NVARCHAR(30));
INSERT #o VALUES
 (1, N'Sunrise Pharmacy', 62, N'Delivered'),        (2, N'Greenleaf Medical Store', 55, N'Delivered'),
 (3, N'Lakeview Clinic', 48, N'Delivered'),         (4, N'Metro Wellness Chemist', 21, N'Shipped'),
 (5, N'Harbor Health Pharmacy', 18, N'Shipped'),    (6, N'Orchid Care Hospital Stores', 15, N'PartiallyShipped'),
 (7, N'Pinecrest Family Pharmacy', 12, N'PartiallyShipped'), (8, N'Riverside Dispensary', 9, N'Confirmed'),
 (9, N'Summit Care Pharmacy', 8, N'Confirmed'),     (10, N'Sunrise Pharmacy', 6, N'Processing'),
 (11, N'Greenleaf Medical Store', 5, N'Processing'),(12, N'Lakeview Clinic', 3, N'Pending'),
 (13, N'Metro Wellness Chemist', 2, N'Pending'),    (14, N'Harbor Health Pharmacy', 1, N'Pending'),
 (15, N'Orchid Care Hospital Stores', 30, N'Cancelled'), (16, N'Old Town Chemists', 70, N'Delivered');

SET IDENTITY_INSERT dbo.Orders ON;
INSERT dbo.Orders (OrderID, CustomerID, OrderDate, Status, BillingAddressID, ShippingAddressID, ModifiedDate)
SELECT o.No, c.CustomerID,
       DATEADD(HOUR, 10 + o.No % 6, DATEADD(DAY, -o.DaysAgo, CAST(CAST(SYSDATETIME() AS date) AS datetime2(0)))),
       o.Status,
       (SELECT MIN(AddressID) FROM dbo.CustomerAddresses a WHERE a.CustomerID = c.CustomerID AND a.AddressType = N'Billing'),
       (SELECT MIN(AddressID) FROM dbo.CustomerAddresses a WHERE a.CustomerID = c.CustomerID AND a.AddressType = N'Shipping'),
       DATEADD(DAY, -o.DaysAgo + 1, SYSDATETIME())
FROM #o o JOIN dbo.Customers c ON c.CustomerName = o.Cust;
SET IDENTITY_INSERT dbo.Orders OFF;

CREATE TABLE #l (No INT, SKU NVARCHAR(40), Qty INT);
INSERT #l VALUES
 (1,N'CAL-PN-002',200),(1,N'CAL-PN-003',100),(1,N'CAL-CD-001',300),
 (2,N'CAL-GI-001',60),(2,N'CAL-GI-002',80),(2,N'CAL-VT-001',40),
 (3,N'CAL-AB-001',30),(3,N'CAL-AB-003',30),(3,N'CAL-PN-008',100),
 (4,N'CAL-PN-006',50),(4,N'CAL-PN-007',30),(4,N'CAL-AC-002',20),
 (5,N'CAL-VT-003',60),(5,N'CAL-VT-004',40),(5,N'CAL-CD-002',100),
 (6,N'CAL-PN-001',150),(6,N'CAL-PN-002',100),(6,N'CAL-AC-001',80),
 (7,N'CAL-GI-001',40),(7,N'CAL-GI-005',30),(7,N'CAL-AB-002',20),
 (8,N'CAL-CD-003',50),(8,N'CAL-CD-004',60),
 (9,N'CAL-PN-009',40),(9,N'CAL-AC-004',100),(9,N'CAL-PN-004',30),
 (10,N'CAL-PN-002',120),(10,N'CAL-PN-005',20),
 (11,N'CAL-AC-003',15),(11,N'CAL-AC-005',60),(11,N'CAL-VT-002',80),
 (12,N'CAL-PN-008',60),(12,N'CAL-PN-003',40),
 (13,N'CAL-AB-004',25),(13,N'CAL-AB-001',20),
 (14,N'CAL-CD-001',100),(14,N'CAL-CD-002',60),(14,N'CAL-VT-001',30),
 (15,N'CAL-PN-007',40),(15,N'CAL-PN-006',40),
 (16,N'CAL-PN-001',60),(16,N'CAL-GI-003',30);

INSERT dbo.OrderLines (OrderID, ProductID, Quantity, UnitPrice)
SELECT l.No, pc.ProductID, l.Qty, pc.UnitPrice
FROM #l l JOIN dbo.ProductCatalog pc ON pc.SKU = l.SKU
ORDER BY l.No, pc.ProductID;

-- Shipments: order, days after order shipped (NULL = not yet), carrier, tracking, status, days after order delivered
CREATE TABLE #s (No INT, ShipDays INT, Carrier NVARCHAR(100), Tracking NVARCHAR(60), Status NVARCHAR(30), DelDays INT);
INSERT #s VALUES
 (1, 1, N'BlueDart',  N'CALD-TRK-100001', N'Delivered', 4),
 (2, 1, N'DTDC',      N'CALD-TRK-100002', N'Delivered', 5),
 (3, 2, N'Delhivery', N'CALD-TRK-100003', N'Delivered', 6),
 (4, 2, N'BlueDart',  N'CALD-TRK-100004', N'Shipped', NULL),
 (5, 3, N'DTDC',      N'CALD-TRK-100005', N'Shipped', NULL),
 (6, 2, N'Delhivery', N'CALD-TRK-100006', N'Delivered', 5),
 (6, NULL, N'Delhivery', NULL,            N'Processing', NULL),
 (7, 3, N'BlueDart',  N'CALD-TRK-100007', N'Shipped', NULL),
 (7, NULL, NULL,      NULL,               N'Pending', NULL),
 (8, NULL, NULL,      NULL,               N'Pending', NULL),
 (10, NULL, N'DTDC',  NULL,               N'Processing', NULL),
 (11, NULL, N'BlueDart', NULL,            N'Processing', NULL),
 (15, NULL, N'DTDC',  NULL,               N'Cancelled', NULL),
 (16, 2, N'DTDC',     N'CALD-TRK-100016', N'Delivered', 6);

INSERT dbo.Shipments (OrderID, ShipmentDate, Carrier, TrackingNumber, Status, DeliveredDate)
SELECT s.No,
       CASE WHEN s.ShipDays IS NULL THEN NULL ELSE DATEADD(DAY, s.ShipDays, o.OrderDate) END,
       s.Carrier, s.Tracking, s.Status,
       CASE WHEN s.DelDays IS NULL THEN NULL ELSE DATEADD(DAY, s.DelDays, o.OrderDate) END
FROM #s s JOIN dbo.Orders o ON o.OrderID = s.No;

COMMIT TRANSACTION;
PRINT 'Seed data loaded.';
GO
