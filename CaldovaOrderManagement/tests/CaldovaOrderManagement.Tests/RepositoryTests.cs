using CaldovaOrderManagement.Web.Data;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace CaldovaOrderManagement.Tests;

public class OrderValidatorTests
{
    private static readonly Dictionary<int, int> Stock = new() { [1] = 10, [2] = 0 };

    private static NewOrderRequest Req(int? customer, params (int? p, int? q)[] lines) =>
        new(customer, null, null, lines.Select(l => new OrderLineInput { ProductId = l.p, Quantity = l.q }).ToList());

    [Fact]
    public void Valid_order_has_no_errors()
    {
        var (errors, lines) = OrderValidator.Validate(Req(5, (1, 3)), Stock);
        Assert.Empty(errors);
        Assert.Single(lines);
    }

    [Fact]
    public void Missing_customer_and_lines_are_reported()
    {
        var (errors, _) = OrderValidator.Validate(Req(null), Stock);
        Assert.Contains("Select a customer.", errors);
        Assert.Contains("Add at least one product line.", errors);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-4)]
    [InlineData(null)]
    public void Non_positive_quantity_is_rejected(int? qty)
    {
        var (errors, _) = OrderValidator.Validate(Req(5, (1, qty)), Stock);
        Assert.Contains(errors, e => e.Contains("quantity"));
    }

    [Fact]
    public void Quantity_above_available_is_rejected()
    {
        var (errors, _) = OrderValidator.Validate(Req(5, (1, 11)), Stock);
        Assert.Contains(errors, e => e.Contains("only 10 available"));
    }

    [Fact]
    public void Out_of_stock_and_unknown_products_are_rejected()
    {
        var (errors, _) = OrderValidator.Validate(Req(5, (2, 1), (99, 1)), Stock);
        Assert.Equal(2, errors.Count);
    }

    [Fact]
    public void Duplicate_products_are_merged_before_checking_availability()
    {
        var (errors, lines) = OrderValidator.Validate(Req(5, (1, 6), (1, 6)), Stock);
        Assert.Single(errors);
        Assert.Equal(12, lines[0].Quantity);
    }
}

public class RepositoryHelperTests
{
    [Fact]
    public void EscapeLike_escapes_wildcards()
    {
        Assert.Equal(@"50\% \_off \[x]", CaldovaRepository.EscapeLike("50% _off [x]"));
    }

    [Fact]
    public async Task Missing_connection_string_gives_clear_message()
    {
        var db = new SqlDb(new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build());
        var ex = await Assert.ThrowsAsync<DatabaseConfigurationException>(() => db.OpenAsync());
        Assert.Contains("ConnectionStrings:CaldovaOrderManagement", DbErrors.ToUserMessage(ex));
    }
}

/// <summary>Runs against a real database only when ConnectionStrings__CaldovaOrderManagement is set.</summary>
public class DatabaseIntegrationTests
{
    private static CaldovaRepository? Repo()
    {
        var cs = Environment.GetEnvironmentVariable("ConnectionStrings__CaldovaOrderManagement");
        if (string.IsNullOrWhiteSpace(cs)) return null;
        var cfg = new Microsoft.Extensions.Configuration.ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:CaldovaOrderManagement"] = cs }).Build();
        return new CaldovaRepository(new SqlDb(cfg));
    }

    [SkippableFact]
    public async Task Required_tables_exist()
    {
        var repo = Repo(); Skip.If(repo is null, "No connection string configured");
        var (db, missing) = await repo!.CheckSchemaAsync();
        Assert.Equal("CaldovaOrderManagement", db);
        Assert.Empty(missing);
    }

    [SkippableFact]
    public async Task Read_queries_succeed()
    {
        var repo = Repo(); Skip.If(repo is null, "No connection string configured");
        Assert.NotNull(await repo!.GetDashboardAsync());
        await repo.GetProductAvailabilityAsync(null);
        await repo.SearchProductsAsync("a");
        await repo.SearchCustomersAsync(null);
        await repo.SearchOrdersAsync(new OrderFilter(null, null, null, null, null, null));
    }

    [SkippableFact]
    public async Task Order_detail_loads_lines_and_shipments_and_valid_order_can_be_placed()
    {
        var repo = Repo(); Skip.If(repo is null, "No connection string configured");
        var first = (await repo!.SearchOrdersAsync(new OrderFilter(null, null, null, null, null, null))).First();
        var detail = await repo.GetOrderDetailAsync(first.OrderId);
        Assert.NotNull(detail);
        Assert.NotEmpty(detail!.Lines);

        // Place a real order for an in-stock product, then remove it so the test leaves no data behind.
        var customer = (await repo.GetActiveCustomersAsync()).First();
        var product = (await repo.GetOrderableProductsAsync()).First(p => p.Available > 0);
        var (id, errors) = await repo.PlaceOrderAsync(new NewOrderRequest(customer.CustomerId, null, null,
            new() { new OrderLineInput { ProductId = product.ProductId, Quantity = 1 } }));
        Assert.Empty(errors);
        Assert.NotNull(id);
        try
        {
            var placed = await repo.GetOrderDetailAsync(id!.Value);
            Assert.Equal("Pending", placed!.Summary.Status);
            Assert.Equal(product.UnitPrice, placed.Lines.Single().UnitPrice);
        }
        finally
        {
            await using var conn = new Microsoft.Data.SqlClient.SqlConnection(
                Environment.GetEnvironmentVariable("ConnectionStrings__CaldovaOrderManagement"));
            await conn.OpenAsync();
            await using var cmd = new Microsoft.Data.SqlClient.SqlCommand(
                "DELETE FROM OrderLines WHERE OrderID = @i; DELETE FROM Orders WHERE OrderID = @i", conn);
            cmd.Parameters.AddWithValue("@i", id!.Value);
            await cmd.ExecuteNonQueryAsync();
        }
    }

    [SkippableFact]
    public async Task Invalid_order_is_rolled_back_and_creates_nothing()
    {
        var repo = Repo(); Skip.If(repo is null, "No connection string configured");
        var before = (await repo!.SearchOrdersAsync(new OrderFilter(null, null, null, null, null, null))).Count;
        var (id, errors) = await repo.PlaceOrderAsync(new NewOrderRequest(int.MaxValue, null, null,
            new() { new OrderLineInput { ProductId = int.MaxValue, Quantity = 1 } }));
        Assert.Null(id);
        Assert.NotEmpty(errors);
        var after = (await repo.SearchOrdersAsync(new OrderFilter(null, null, null, null, null, null))).Count;
        Assert.Equal(before, after);
    }
}

