# Caldova database scripts

SQL Server scripts for the `CaldovaOrderManagement` database. **Demonstration data only.**

## Run order
1. `01_create_database.sql` – creates the database. Raises an error and changes nothing if it already exists.
2. `02_create_schema.sql` – creates the `dbo` tables, constraints and indexes. Refuses to run if the database already has tables.
3. `03_seed_data.sql` – loads sample data in one transaction. Refuses to run if products or customers already exist.

```powershell
foreach ($s in '01_create_database.sql','02_create_schema.sql','03_seed_data.sql') {
    sqlcmd -S localhost -E -C -b -I -i $s
    if ($LASTEXITCODE -ne 0) { break }
}
```
`-E` is Windows authentication, `-C` trusts the server certificate, `-b` stops on error and `-I` enables `QUOTED_IDENTIFIER` (needed for the filtered indexes). [Run-Setup.ps1](./Run-Setup.ps1) does the same (`-Server`, `-SkipSeed`; it may need `powershell -ExecutionPolicy Bypass -File`).

Nothing in these scripts drops or overwrites an existing database.

## What is inferred
Only `CustomerAddresses` columns `AddressID`, `CustomerID`, `AddressType`, `AddressLine1`, `AddressLine2` were visible in the reference. Everything else follows the proposed design and is **not verified source metadata**.

| Table | Notes |
|---|---|
| ProductCategories | `CategoryName` unique. |
| ProductCatalog | FK to category; `SKU` unique; `UnitPrice DECIMAL(10,2) >= 0`. |
| ProductDescriptions | One row per product and `LanguageCode` (`en-US` in the seed) with `ShortDescription`, `LongDescription` and optional `Specifications`. Searched with plain `LIKE` by the app. Embeddings live in a separate table, `dbo.ProductDescriptionEmbeddings` (FKs to `ProductCatalog` and `ProductDescriptions`, `VECTOR(1536)`), created by [Embedding_Script.sql](../Embedding_Script.sql) (needs Azure SQL / SQL Server 2025 vector support and an Azure OpenAI embedding deployment). |
| Inventory | One row per product per `LocationName`; `QuantityOnHand`, `QuantityReserved`, `ReorderLevel` >= 0 and `QuantityReserved <= QuantityOnHand`, so available quantity can never be negative. |
| Customers | `Email` unique when present. |
| CustomerAddresses | `AddressType` is `Billing` or `Shipping`; a customer may have several of each. |
| Orders | Status: Pending, Processing, Confirmed, PartiallyShipped, Shipped, Delivered, Cancelled. Billing/shipping addresses are nullable and use composite FKs `(AddressID, CustomerID)`, so an order can only use its own customer's addresses. Address *type* is not enforced by the database. |
| OrderLines | `Quantity > 0`, `UnitPrice >= 0`, one line per product per order. The price is stored per line as the price at order time. Order totals are not stored; they are calculated. |
| Shipments | Many per order. Status: Pending, Processing, Shipped, Delivered, Cancelled. Shipped/Delivered require `ShipmentDate`; Delivered requires `DeliveredDate >= ShipmentDate`. Tracking number is unique when present. |

Other assumptions: dates are `DATETIME2(0)` local server time; inventory is not linked to orders (reserved quantities are static demo values); currency is not modelled (sample prices are fictional, written as INR-scale numbers).

## Seed data summary
6 categories, 31 tablet products (e.g. Paracetamol, Dolo 650, Crocin Advance, Calpol, Saridon, Zerodol-P/SP, Combiflam, Allegra, Pantop, Augmentin, Shelcal, Telma), 31 descriptions (one `en-US` row per product), 59 inventory rows across Mumbai/Delhi/Bengaluru (with out-of-stock and low-stock products and one inactive product), 10 fictional customers (one inactive) with 22 addresses, 16 orders covering every status, 42 order lines and 14 shipments covering every shipment status (including an order with no shipments and orders with several).

Brand names are used only as recognizable examples. SKUs (`CAL-…`), prices, stock, customers and orders are fictional; nothing here is medical advice, real inventory or current market pricing.
