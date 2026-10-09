namespace CaldovaOrderManagement.Web.Data;

public record ProductRow(int ProductId, string Sku, string Name, string Category, decimal UnitPrice,
    bool IsActive, int Available, int ReorderLevel)
{
    public string StockState => Available <= 0 ? "Out of stock" : Available <= ReorderLevel ? "Low stock" : "In stock";
    public string StockCss => Available <= 0 ? "bad" : Available <= ReorderLevel ? "warn" : "ok";
}

public record ProductOption(int ProductId, string Sku, string Name, decimal UnitPrice, int Available);

public record CustomerOption(int CustomerId, string Name);

public record AddressRow(int AddressId, int CustomerId, string Type, string Line1, string? Line2, string City,
    string? State, string? PostalCode, string Country)
{
    public string Formatted => string.Join(", ",
        new[] { Line1, Line2, City, State, PostalCode, Country }.Where(s => !string.IsNullOrWhiteSpace(s)));
}

public record CustomerRow(int CustomerId, string Name, string? Email, string? Phone, bool IsActive,
    int OrderCount, List<AddressRow> Addresses);

public record OrderSummary(int OrderId, int CustomerId, string CustomerName, DateTime OrderDate, string Status,
    int LineCount, decimal Total);

public record OrderLineRow(int OrderLineId, int ProductId, string Sku, string ProductName, int Quantity,
    decimal UnitPrice)
{
    public decimal LineTotal => Quantity * UnitPrice;
}

public record ShipmentRow(int ShipmentId, DateTime? ShipmentDate, string? Carrier, string? TrackingNumber,
    string Status, DateTime? DeliveredDate);

public record OrderDetail(OrderSummary Summary, string? CustomerEmail, AddressRow? Billing, AddressRow? Shipping,
    List<OrderLineRow> Lines, List<ShipmentRow> Shipments);

public record CategoryCount(string Name, int Count);

public record DashboardData(int TotalProducts, int AvailableProducts, int OpenOrders, int PendingShipments,
    List<CategoryCount> ProductsByCategory, List<CategoryCount> OrdersByStatus);

public record OrderFilter(int? OrderId, int? CustomerId, string? Customer, string? Status, DateTime? From, DateTime? To);

public class OrderLineInput
{
    public int? ProductId { get; set; }
    public int? Quantity { get; set; }
}

public record NewOrderRequest(int? CustomerId, int? BillingAddressId, int? ShippingAddressId,
    List<OrderLineInput> Lines);

public static class OrderStatuses
{
    public static readonly string[] All =
        { "Pending", "Processing", "Confirmed", "PartiallyShipped", "Shipped", "Delivered", "Cancelled" };

    // Orders still in progress (not fully shipped or finished).
    public static readonly string[] Open = { "Pending", "Processing", "Confirmed", "PartiallyShipped" };

    public static readonly string[] PendingShipment = { "Pending", "Processing" };

    public static string Css(string? s) => s switch
    {
        "Delivered" => "ok",
        "Shipped" => "info",
        "PartiallyShipped" => "info",
        "Cancelled" => "bad",
        "Pending" => "warn",
        _ => "neutral"
    };
}
