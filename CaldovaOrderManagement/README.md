# Caldova Order Management (.NET 8, Razor Pages)

Internal operations app for the `CaldovaOrderManagement` SQL Server database. Targets .NET 8 (kept there deliberately for later modernization).

## Schema the app relies on
The SQL scripts in [database/](../database/README.md) (a sibling folder of this project) create and seed the database (design and assumptions are documented there). The app follows that design:

`ProductCategories` ← `ProductCatalog` ← `ProductDescriptions` (one row per product and `LanguageCode`: `ShortDescription`, `LongDescription`, `Specifications`), `Inventory` (multiple locations per product);
`Customers` ← `CustomerAddresses` (Billing/Shipping); `Customers` ← `Orders` (→ billing/shipping `CustomerAddresses`) ← `OrderLines` (→ `ProductCatalog`), `Shipments` (many per order).

Columns used are exactly those in that design. **Verify against your real scripts**; the Dashboard shows missing tables, and a missing column yields a clear "schema differs" error.

Assumptions: available quantity = SUM(`QuantityOnHand` − `QuantityReserved`) over all locations; low stock = available ≤ SUM(`ReorderLevel`); open orders = Pending/Processing/Confirmed/PartiallyShipped; pending shipments = Shipment status Pending/Processing.

## Configure the connection (no secrets in source)
Key: `ConnectionStrings:CaldovaOrderManagement` (env var `ConnectionStrings__CaldovaOrderManagement`). `Initial Catalog` must be `CaldovaOrderManagement`.

User secrets (recommended for development):
```
cd src\CaldovaOrderManagement.Web
dotnet user-secrets set "ConnectionStrings:CaldovaOrderManagement" "Server=<server>;Database=CaldovaOrderManagement;Integrated Security=True;TrustServerCertificate=True;Encrypt=True"
```
or SQL authentication: `Server=<server>;Database=CaldovaOrderManagement;User ID=<user>;Password=<password>;Encrypt=True`.

The header environment label is configurable via `Application:EnvironmentLabel` (default: "SQL Server · CaldovaOrderManagement").

## Run / test
```
dotnet run --project src\CaldovaOrderManagement.Web
dotnet test
```
Database integration tests are skipped unless `ConnectionStrings__CaldovaOrderManagement` is set. They are read-only except one test that submits an invalid order and asserts nothing is saved.

## Behavior notes
- The app never creates, migrates or seeds the database.
- New orders are inserted as `Pending` with their lines in one transaction (rolled back on any failure). Line prices are copied from the current `ProductCatalog.UnitPrice`.
- **Stock is validated but not deducted or reserved**: the schema has no reservation workflow tied to orders, so `Inventory` is never modified.
- Traditional search is a parameterized `LIKE` on `ProductCatalog.ProductName` only (no SKU, category or description matching), and its results hide the category. Semantic search uses the separate `dbo.ProductDescriptionEmbeddings` table created by `Embedding_Script.sql` (the app itself does not create it).
- The dashboard charts load Chart.js from a CDN.
