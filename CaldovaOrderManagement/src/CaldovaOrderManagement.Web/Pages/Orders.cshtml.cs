using CaldovaOrderManagement.Web.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CaldovaOrderManagement.Web.Pages;

public class OrdersModel : PageModel
{
    private readonly CaldovaRepository _repo;
    private readonly ILogger<OrdersModel> _log;
    public OrdersModel(CaldovaRepository repo, ILogger<OrdersModel> log) { _repo = repo; _log = log; }

    [BindProperty(SupportsGet = true)] public int? OrderId { get; set; }
    [BindProperty(SupportsGet = true)] public int? CustomerId { get; set; }
    [BindProperty(SupportsGet = true)] public string? Customer { get; set; }
    [BindProperty(SupportsGet = true)] public string? Status { get; set; }
    [BindProperty(SupportsGet = true)] public DateTime? From { get; set; }
    [BindProperty(SupportsGet = true)] public DateTime? To { get; set; }

    public List<OrderSummary> Orders { get; private set; } = new();
    public string? CustomerFilterName { get; private set; }
    public string? Error { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        try
        {
            if (Status != null && !OrderStatuses.All.Contains(Status)) Status = null;
            Customer = Customer?.Trim();
            if (Customer is { Length: > 100 }) Customer = Customer[..100];
            Orders = await _repo.SearchOrdersAsync(new OrderFilter(OrderId, CustomerId, Customer, Status, From, To), ct);
            if (CustomerId.HasValue)
                CustomerFilterName = Orders.FirstOrDefault()?.CustomerName ?? "no matching orders";
        }
        catch (Exception ex) { _log.LogError(ex, "Order lookup failed"); Error = DbErrors.ToUserMessage(ex); }
    }
}
