namespace CaldovaOrderManagement.Web.Data;

public static class OrderValidator
{
    public const int MaxQuantityPerLine = 100000;

    /// <summary>
    /// Validates an order request. Duplicate products are merged. <paramref name="available"/> maps ProductID to
    /// available quantity for active products only (a product missing from it is unknown/inactive).
    /// </summary>
    public static (List<string> Errors, List<(int ProductId, int Quantity)> Lines) Validate(
        NewOrderRequest req, IReadOnlyDictionary<int, int> available)
    {
        var errors = new List<string>();
        if (req.CustomerId is null or <= 0) errors.Add("Select a customer.");

        var rows = req.Lines.Where(l => l.ProductId.HasValue || l.Quantity.HasValue).ToList();
        if (rows.Count == 0) errors.Add("Add at least one product line.");

        var merged = new Dictionary<int, int>();
        foreach (var (l, i) in rows.Select((l, i) => (l, i + 1)))
        {
            if (l.ProductId is null or <= 0) { errors.Add($"Line {i}: select a product."); continue; }
            if (l.Quantity is null or <= 0) { errors.Add($"Line {i}: quantity must be a whole number greater than zero."); continue; }
            if (l.Quantity > MaxQuantityPerLine) { errors.Add($"Line {i}: quantity is too large."); continue; }
            merged[l.ProductId.Value] = merged.GetValueOrDefault(l.ProductId.Value) + l.Quantity.Value;
        }

        foreach (var (pid, qty) in merged)
        {
            if (!available.TryGetValue(pid, out var avail))
                errors.Add($"Product {pid} does not exist or is not active.");
            else if (qty > avail)
                errors.Add($"Product {pid}: requested {qty} but only {Math.Max(avail, 0)} available.");
        }

        return (errors, merged.Select(kv => (kv.Key, kv.Value)).ToList());
    }
}
