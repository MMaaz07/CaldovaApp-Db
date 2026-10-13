using Microsoft.Data.SqlClient;

namespace CaldovaOrderManagement.Web.Data;

public class CaldovaRepository
{
    private readonly SqlDb _db;
    public CaldovaRepository(SqlDb db) => _db = db;

    public static readonly string[] RequiredTables =
    {
        "ProductCategories", "ProductCatalog", "ProductDescriptions", "Inventory",
        "Customers", "CustomerAddresses", "Orders", "OrderLines", "Shipments"
    };

    private static SqlParameter P(string name, object? value) => new(name, value ?? DBNull.Value);
    private static string? S(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
    private static int I(SqlDataReader r, int i) => r.IsDBNull(i) ? 0 : Convert.ToInt32(r.GetValue(i));
    private static decimal D(SqlDataReader r, int i) => r.IsDBNull(i) ? 0m : Convert.ToDecimal(r.GetValue(i));
    private static DateTime? Dt(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetDateTime(i);

    public static string EscapeLike(string term) =>
        term.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_").Replace("[", "\\[");

    // ---- Connectivity / schema check ----
    public async Task<(string Database, List<string> MissingTables)> CheckSchemaAsync(CancellationToken ct = default)
    {
        await using var conn = await _db.OpenAsync(ct);
        var present = await SqlDb.QueryAsync(conn, null,
            "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'",
            r => r.GetString(0), null, ct);
        var missing = RequiredTables.Where(t => !present.Contains(t, StringComparer.OrdinalIgnoreCase)).ToList();
        return (conn.Database, missing);
    }

    // ---- Dashboard ----
    public async Task<DashboardData> GetDashboardAsync(CancellationToken ct = default)
    {
        var open = string.Join(",", OrderStatuses.Open.Select(s => $"'{s}'"));
        var pend = string.Join(",", OrderStatuses.PendingShipment.Select(s => $"'{s}'"));
        // Status lists are compile-time constants, not user input.
        var counts = (await _db.QueryAsync($@"
            SELECT
              (SELECT COUNT(*) FROM ProductCatalog),
              (SELECT COUNT(*) FROM ProductCatalog p WHERE p.IsActive = 1 AND
                 (SELECT ISNULL(SUM(i.QuantityOnHand - i.QuantityReserved),0) FROM Inventory i WHERE i.ProductID = p.ProductID) > 0),
              (SELECT COUNT(*) FROM Orders WHERE Status IN ({open})),
              (SELECT COUNT(*) FROM Shipments WHERE Status IN ({pend}))",
            r => new[] { I(r, 0), I(r, 1), I(r, 2), I(r, 3) }, null, ct))[0];

        var cats = await _db.QueryAsync(@"
            SELECT c.CategoryName, COUNT(p.ProductID) FROM ProductCategories c
            LEFT JOIN ProductCatalog p ON p.CategoryID = c.CategoryID
            GROUP BY c.CategoryName ORDER BY c.CategoryName",
            r => new CategoryCount(S(r, 0) ?? "", I(r, 1)), null, ct);
        var statuses = await _db.QueryAsync(
            "SELECT Status, COUNT(*) FROM Orders GROUP BY Status ORDER BY Status",
            r => new CategoryCount(S(r, 0) ?? "(none)", I(r, 1)), null, ct);

        return new DashboardData(counts[0], counts[1], counts[2], counts[3], cats, statuses);
    }

    // ---- Products ----
    private const string ProductSelect = @"
        SELECT p.ProductID, p.SKU, p.ProductName, c.CategoryName, p.UnitPrice, p.IsActive,
               ISNULL(SUM(i.QuantityOnHand - i.QuantityReserved), 0) AS Available,
               ISNULL(SUM(i.ReorderLevel), 0) AS Reorder
        FROM ProductCatalog p
        JOIN ProductCategories c ON c.CategoryID = p.CategoryID
        LEFT JOIN Inventory i ON i.ProductID = p.ProductID";

    private const string ProductGroup = " GROUP BY p.ProductID, p.SKU, p.ProductName, c.CategoryName, p.UnitPrice, p.IsActive";

    private static ProductRow MapProduct(SqlDataReader r) =>
        new(I(r, 0), S(r, 1) ?? "", S(r, 2) ?? "", S(r, 3) ?? "", D(r, 4), !r.IsDBNull(5) && r.GetBoolean(5), I(r, 6), I(r, 7));

    /// <param name="stock">null/"all", "out", "low" or "in".</param>
    public Task<List<ProductRow>> GetProductAvailabilityAsync(string? stock, CancellationToken ct = default)
    {
        var having = stock switch
        {
            "out" => " HAVING ISNULL(SUM(i.QuantityOnHand - i.QuantityReserved),0) <= 0",
            "low" => " HAVING ISNULL(SUM(i.QuantityOnHand - i.QuantityReserved),0) > 0 AND ISNULL(SUM(i.QuantityOnHand - i.QuantityReserved),0) <= ISNULL(SUM(i.ReorderLevel),0)",
            "in" => " HAVING ISNULL(SUM(i.QuantityOnHand - i.QuantityReserved),0) > ISNULL(SUM(i.ReorderLevel),0)",
            _ => ""
        };
        return _db.QueryAsync(ProductSelect + ProductGroup + having + " ORDER BY p.ProductName", MapProduct, null, ct);
    }

    public Task<List<ProductRow>> SearchProductsAsync(string term, CancellationToken ct = default)
    {
        var sql = ProductSelect + @"
            WHERE p.ProductName LIKE @t ESCAPE '\'"
            + ProductGroup + " ORDER BY p.ProductName";
        return _db.QueryAsync(sql, MapProduct, new[] { P("@t", "%" + EscapeLike(term) + "%") }, ct);
    }

    public async Task<List<ProductOption>> GetOrderableProductsAsync(CancellationToken ct = default)
    {
        var rows = await _db.QueryAsync(ProductSelect + " WHERE p.IsActive = 1" + ProductGroup + " ORDER BY p.ProductName",
            MapProduct, null, ct);
        return rows.Select(p => new ProductOption(p.ProductId, p.Sku, p.Name, p.UnitPrice, p.Available)).ToList();
    }

    // ---- Customers ----
    public Task<List<CustomerOption>> GetActiveCustomersAsync(CancellationToken ct = default) =>
        _db.QueryAsync("SELECT CustomerID, CustomerName FROM Customers WHERE IsActive = 1 ORDER BY CustomerName",
            r => new CustomerOption(I(r, 0), S(r, 1) ?? ""), null, ct);

    private static AddressRow MapAddress(SqlDataReader r) =>
        new(I(r, 0), I(r, 1), S(r, 2) ?? "", S(r, 3) ?? "", S(r, 4), S(r, 5) ?? "", S(r, 6), S(r, 7), S(r, 8) ?? "");

    private const string AddressSelect =
        "SELECT AddressID, CustomerID, AddressType, AddressLine1, AddressLine2, City, StateProvince, PostalCode, Country FROM CustomerAddresses";

    public Task<List<AddressRow>> GetAddressesForCustomerAsync(int customerId, CancellationToken ct = default) =>
        _db.QueryAsync(AddressSelect + " WHERE CustomerID = @c ORDER BY AddressType, AddressID", MapAddress,
            new[] { P("@c", customerId) }, ct);

    public async Task<List<CustomerRow>> SearchCustomersAsync(string? term, CancellationToken ct = default)
    {
        var ps = new List<SqlParameter>();
        var where = "";
        if (!string.IsNullOrWhiteSpace(term))
        {
            where = @"WHERE c.CustomerName LIKE @t ESCAPE '\' OR c.Email LIKE @t ESCAPE '\' OR c.Phone LIKE @t ESCAPE '\'";
            ps.Add(P("@t", "%" + EscapeLike(term.Trim()) + "%"));
            if (int.TryParse(term.Trim(), out var id)) { where += " OR c.CustomerID = @id"; ps.Add(P("@id", id)); }
        }
        var customers = await _db.QueryAsync($@"
            SELECT TOP 50 c.CustomerID, c.CustomerName, c.Email, c.Phone, c.IsActive,
                   (SELECT COUNT(*) FROM Orders o WHERE o.CustomerID = c.CustomerID)
            FROM Customers c {where} ORDER BY c.CustomerName",
            r => new CustomerRow(I(r, 0), S(r, 1) ?? "", S(r, 2), S(r, 3), !r.IsDBNull(4) && r.GetBoolean(4), I(r, 5), new()),
            ps, ct);
        if (customers.Count == 0) return customers;

        var idParams = customers.Select((c, i) => P($"@c{i}", c.CustomerId)).ToList();
        var addrs = await _db.QueryAsync(
            AddressSelect + $" WHERE CustomerID IN ({string.Join(",", idParams.Select(p => p.ParameterName))}) ORDER BY AddressType, AddressID",
            MapAddress, idParams, ct);
        foreach (var c in customers) c.Addresses.AddRange(addrs.Where(a => a.CustomerId == c.CustomerId));
        return customers;
    }

    // ---- Orders ----
    public async Task<List<OrderSummary>> SearchOrdersAsync(OrderFilter f, CancellationToken ct = default)
    {
        var where = new List<string>();
        var ps = new List<SqlParameter>();
        if (f.OrderId.HasValue) { where.Add("o.OrderID = @id"); ps.Add(P("@id", f.OrderId)); }
        if (f.CustomerId.HasValue) { where.Add("o.CustomerID = @cid"); ps.Add(P("@cid", f.CustomerId)); }
        if (!string.IsNullOrWhiteSpace(f.Customer))
        {
            where.Add(@"(c.CustomerName LIKE @cust ESCAPE '\' OR c.Email LIKE @cust ESCAPE '\')");
            ps.Add(P("@cust", "%" + EscapeLike(f.Customer.Trim()) + "%"));
        }
        if (!string.IsNullOrWhiteSpace(f.Status)) { where.Add("o.Status = @st"); ps.Add(P("@st", f.Status)); }
        if (f.From.HasValue) { where.Add("o.OrderDate >= @from"); ps.Add(P("@from", f.From.Value.Date)); }
        if (f.To.HasValue) { where.Add("o.OrderDate < @to"); ps.Add(P("@to", f.To.Value.Date.AddDays(1))); }

        var sql = $@"
            SELECT TOP 200 o.OrderID, o.CustomerID, c.CustomerName, o.OrderDate, o.Status,
                   (SELECT COUNT(*) FROM OrderLines l WHERE l.OrderID = o.OrderID),
                   (SELECT ISNULL(SUM(l.Quantity * l.UnitPrice), 0) FROM OrderLines l WHERE l.OrderID = o.OrderID)
            FROM Orders o JOIN Customers c ON c.CustomerID = o.CustomerID
            {(where.Count > 0 ? "WHERE " + string.Join(" AND ", where) : "")}
            ORDER BY o.OrderDate DESC, o.OrderID DESC";
        return await _db.QueryAsync(sql, MapOrderSummary, ps, ct);
    }

    private static OrderSummary MapOrderSummary(SqlDataReader r) =>
        new(I(r, 0), I(r, 1), S(r, 2) ?? "", r.GetDateTime(3), S(r, 4) ?? "", I(r, 5), D(r, 6));

    public async Task<OrderDetail?> GetOrderDetailAsync(int orderId, CancellationToken ct = default)
    {
        SqlParameter[] P1() => new[] { P("@id", orderId) };
        var head = await _db.QueryAsync(@"
            SELECT o.OrderID, o.CustomerID, c.CustomerName, o.OrderDate, o.Status,
                   (SELECT COUNT(*) FROM OrderLines l WHERE l.OrderID = o.OrderID),
                   (SELECT ISNULL(SUM(l.Quantity * l.UnitPrice), 0) FROM OrderLines l WHERE l.OrderID = o.OrderID),
                   c.Email, o.BillingAddressID, o.ShippingAddressID
            FROM Orders o JOIN Customers c ON c.CustomerID = o.CustomerID WHERE o.OrderID = @id",
            r => (Summary: MapOrderSummary(r), Email: S(r, 7),
                  Bill: r.IsDBNull(8) ? (int?)null : I(r, 8), Ship: r.IsDBNull(9) ? (int?)null : I(r, 9)),
                              P1(), ct);
        if (head.Count == 0) return null;
        var h = head[0];

        var lines = await _db.QueryAsync(@"
            SELECT l.OrderLineID, l.ProductID, pc.SKU, pc.ProductName, l.Quantity, l.UnitPrice
            FROM OrderLines l JOIN ProductCatalog pc ON pc.ProductID = l.ProductID
            WHERE l.OrderID = @id ORDER BY l.OrderLineID",
            r => new OrderLineRow(I(r, 0), I(r, 1), S(r, 2) ?? "", S(r, 3) ?? "", I(r, 4), D(r, 5)), P1(), ct);
        var ships = await _db.QueryAsync(@"
            SELECT ShipmentID, ShipmentDate, Carrier, TrackingNumber, Status, DeliveredDate
            FROM Shipments WHERE OrderID = @id ORDER BY ShipmentID",
            r => new ShipmentRow(I(r, 0), Dt(r, 1), S(r, 2), S(r, 3), S(r, 4) ?? "", Dt(r, 5)), P1(), ct);

        async Task<AddressRow?> Addr(int? id) => id is null ? null
            : (await _db.QueryAsync(AddressSelect + " WHERE AddressID = @a", MapAddress, new[] { P("@a", id) }, ct)).FirstOrDefault();

        return new OrderDetail(h.Summary, h.Email, await Addr(h.Bill), await Addr(h.Ship), lines, ships);
    }

    // ---- Place order (single transaction) ----
    public async Task<(int? OrderId, List<string> Errors)> PlaceOrderAsync(NewOrderRequest req, CancellationToken ct = default)
    {
        await using var conn = await _db.OpenAsync(ct);
        await using var tx = (SqlTransaction)await conn.BeginTransactionAsync(ct);
        try
        {
            var productIds = req.Lines.Where(l => l.ProductId > 0).Select(l => l.ProductId!.Value).Distinct().ToList();
            var available = new Dictionary<int, int>();
            var prices = new Dictionary<int, decimal>();
            if (productIds.Count > 0)
            {
                var ps = productIds.Select((id, i) => P($"@p{i}", id)).ToList();
                var rows = await SqlDb.QueryAsync(conn, tx, $@"
                    SELECT p.ProductID, p.UnitPrice, ISNULL(SUM(i.QuantityOnHand - i.QuantityReserved), 0)
                    FROM ProductCatalog p LEFT JOIN Inventory i ON i.ProductID = p.ProductID
                    WHERE p.IsActive = 1 AND p.ProductID IN ({string.Join(",", ps.Select(x => x.ParameterName))})
                    GROUP BY p.ProductID, p.UnitPrice",
                    r => (Id: I(r, 0), Price: D(r, 1), Avail: I(r, 2)), ps, ct);
                foreach (var row in rows) { available[row.Id] = row.Avail; prices[row.Id] = row.Price; }
            }

            var (errors, lines) = OrderValidator.Validate(req, available);

            if (req.CustomerId > 0)
            {
                var active = await SqlDb.QueryAsync(conn, tx, "SELECT IsActive FROM Customers WHERE CustomerID = @c",
                    r => !r.IsDBNull(0) && r.GetBoolean(0), new[] { P("@c", req.CustomerId) }, ct);
                if (active.Count == 0 || !active[0]) errors.Add("The selected customer does not exist or is inactive.");
                else
                {
                    foreach (var (id, label) in new[] { (req.BillingAddressId, "billing"), (req.ShippingAddressId, "shipping") })
                    {
                        if (id is null) continue;
                        var ok = await SqlDb.QueryAsync(conn, tx,
                            "SELECT 1 FROM CustomerAddresses WHERE AddressID = @a AND CustomerID = @c",
                            r => 1, new[] { P("@a", id), P("@c", req.CustomerId) }, ct);
                        if (ok.Count == 0) errors.Add($"The selected {label} address does not belong to this customer.");
                    }
                }
            }

            if (errors.Count > 0) { await tx.RollbackAsync(ct); return (null, errors); }

            await using var ins = new SqlCommand(@"
                INSERT INTO Orders (CustomerID, OrderDate, Status, BillingAddressID, ShippingAddressID, ModifiedDate)
                OUTPUT INSERTED.OrderID
                VALUES (@c, GETDATE(), 'Pending', @b, @s, GETDATE())", conn, tx);
            ins.Parameters.Add(P("@c", req.CustomerId));
            ins.Parameters.Add(P("@b", req.BillingAddressId));
            ins.Parameters.Add(P("@s", req.ShippingAddressId));
            var orderId = Convert.ToInt32(await ins.ExecuteScalarAsync(ct));

            foreach (var (pid, qty) in lines)
            {
                await using var li = new SqlCommand(
                    "INSERT INTO OrderLines (OrderID, ProductID, Quantity, UnitPrice) VALUES (@o, @p, @q, @u)", conn, tx);
                li.Parameters.Add(P("@o", orderId));
                li.Parameters.Add(P("@p", pid));
                li.Parameters.Add(P("@q", qty));
                li.Parameters.Add(new SqlParameter("@u", System.Data.SqlDbType.Decimal) { Value = prices[pid], Precision = 18, Scale = 2 });
                await li.ExecuteNonQueryAsync(ct);
            }

            await tx.CommitAsync(ct);
            return (orderId, new List<string>());
        }
        catch
        {
            try { await tx.RollbackAsync(CancellationToken.None); } catch { /* connection already broken */ }
            throw;
        }
    }
}
